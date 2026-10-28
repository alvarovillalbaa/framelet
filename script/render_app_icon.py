#!/usr/bin/env python3
"""Rasterize Framelet's simple SVG master into an RGBA PNG using the standard library."""

import argparse
import math
from pathlib import Path
import re
import struct
import xml.etree.ElementTree as ET
import zlib


MASTER = Path(__file__).resolve().parent.parent / "artwork/app-icon.svg"
SVG = "{http://www.w3.org/2000/svg}"
SAMPLES = 4
SAMPLE_COUNT = SAMPLES * SAMPLES
ICON_SLOTS = (
    (b"icp4", "icon_16x16.png", 16),
    (b"ic11", "icon_16x16@2x.png", 32),
    (b"icp5", "icon_32x32.png", 32),
    (b"ic12", "icon_32x32@2x.png", 64),
    (b"ic07", "icon_128x128.png", 128),
    (b"ic13", "icon_128x128@2x.png", 256),
    (b"ic08", "icon_256x256.png", 256),
    (b"ic14", "icon_256x256@2x.png", 512),
    (b"ic09", "icon_512x512.png", 512),
    (b"ic10", "icon_512x512@2x.png", 1024),
)


def shapes():
    root = ET.parse(MASTER).getroot()
    if root.tag != SVG + "svg" or root.attrib != {
        "width": "1024", "height": "1024", "viewBox": "0 0 1024 1024"
    }:
        raise ValueError("The SVG must use an untransformed 1024-square viewBox.")
    result = []
    for element in root:
        if element.tag in (SVG + "title", SVG + "desc"):
            continue
        if len(element):
            raise ValueError("Nested artwork is unsupported.")
        if element.tag == SVG + "rect" and not set(element.attrib) - {"x", "y", "width", "height", "rx", "fill"}:
            x, y, width, height, radius = (float(element.get(key, "0")) for key in ("x", "y", "width", "height", "rx"))
        elif element.tag == SVG + "circle" and not set(element.attrib) - {"cx", "cy", "r", "fill"}:
            cx, cy, radius = (float(element.get(key, "0")) for key in ("cx", "cy", "r"))
            x, y, width, height = cx - radius, cy - radius, 2 * radius, 2 * radius
        else:
            raise ValueError("Only solid rounded rectangles and circles are supported.")
        if not all(math.isfinite(value) for value in (x, y, width, height, radius)):
            raise ValueError("Artwork coordinates must be finite.")
        if not (0 <= x < x + width <= 1024 and 0 <= y < y + height <= 1024 and 0 <= radius <= min(width, height) / 2):
            raise ValueError("Artwork geometry must fit inside the viewBox.")
        fill = element.get("fill", "")
        if not re.fullmatch(r"#[0-9A-Fa-f]{6}", fill):
            raise ValueError("Only opaque RGB fills are supported.")
        color = bytes(int(fill[index:index + 2], 16) for index in (1, 3, 5))
        result.append((x, y, width, height, radius, color))
    if not 1 <= len(result) <= 32:
        raise ValueError("Keep the icon between one and 32 simple shapes.")
    return result


def render(size):
    pixels = bytearray(size * size * 4)
    scale = size / 1024
    for x, y, width, height, radius, color in shapes():
        x, y, width, height, radius = (value * scale for value in (x, y, width, height, radius))
        for row in range(math.floor(y), math.ceil(y + height)):
            for column in range(math.floor(x), math.ceil(x + width)):
                full_pixel = x <= column and column + 1 <= x + width and y <= row and row + 1 <= y + height
                interior = (x + radius <= column and column + 1 <= x + width - radius) or (y + radius <= row and row + 1 <= y + height - radius)
                coverage = SAMPLE_COUNT if full_pixel and interior else 0
                if not coverage:
                    for sy in range(SAMPLES):
                        py = row + (sy + 0.5) / SAMPLES
                        dy = max(y + radius - py, 0, py - (y + height - radius))
                        for sx in range(SAMPLES):
                            px = column + (sx + 0.5) / SAMPLES
                            dx = max(x + radius - px, 0, px - (x + width - radius))
                            if x <= px < x + width and y <= py < y + height and dx * dx + dy * dy <= radius * radius:
                                coverage += 1
                if not coverage:
                    continue
                offset = (row * size + column) * 4
                alpha = (coverage * 255 + SAMPLE_COUNT // 2) // SAMPLE_COUNT
                old_alpha = pixels[offset + 3]
                combined = alpha + (old_alpha * (255 - alpha) + 127) // 255
                for channel in range(3):
                    premultiplied = color[channel] * alpha + (pixels[offset + channel] * old_alpha * (255 - alpha) + 127) // 255
                    pixels[offset + channel] = min(255, (premultiplied + combined // 2) // combined)
                pixels[offset + 3] = combined
    return pixels


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def encode(pixels, size):
    rows = b"".join(b"\0" + pixels[row * size * 4:(row + 1) * size * 4] for row in range(size))
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"sRGB", b"\0")
        + chunk(b"IDAT", zlib.compress(rows, 9))
        + chunk(b"IEND", b"")
    )


def pack_iconset(directory):
    # ICNS header/element lengths include their eight-byte big-endian headers.
    # PNG slot tags follow the documented primary decoder reference in the receipt.
    elements = []
    for code, name, size in ICON_SLOTS:
        data = (directory / name).read_bytes()
        if data[:16] != b"\x89PNG\r\n\x1a\n\0\0\0\rIHDR":
            raise ValueError(f"Invalid generated PNG: {name}")
        if struct.unpack(">IIBBBBB", data[16:29]) != (size, size, 8, 6, 0, 0, 0):
            raise ValueError(f"Unexpected generated dimensions or format: {name}")
        elements.append(code + struct.pack(">I", len(data) + 8) + data)
    body = b"".join(elements)
    return b"icns" + struct.pack(">I", len(body) + 8) + body


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--size", type=int, choices=[16, 32, 64, 128, 256, 512, 1024])
    mode.add_argument("--pack-iconset", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.write_bytes(pack_iconset(args.pack_iconset) if args.pack_iconset else encode(render(args.size), args.size))
