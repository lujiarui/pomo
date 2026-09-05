#!/usr/bin/env python3
"""Generate Pomo's small code-native app icon without external dependencies."""

import math
import struct
import zlib
from pathlib import Path

SIZE = 1024
OUTPUT = Path(__file__).resolve().parent.parent / "Assets" / "AppIcon-1024.png"


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    t = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def rounded_box_distance(x: float, y: float, half: float, radius: float) -> float:
    qx = abs(x) - (half - radius)
    qy = abs(y) - (half - radius)
    return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - radius


def create_png() -> bytes:
    rows = []
    center = SIZE / 2
    for py in range(SIZE):
        row = bytearray([0])
        y = py + 0.5 - center
        for px in range(SIZE):
            x = px + 0.5 - center
            box_d = rounded_box_distance(x, y, 430, 190)
            box_alpha = 1.0 - smoothstep(-1.0, 1.0, box_d)

            radial = min(1.0, math.hypot(x + 120, y + 150) / 850)
            red = int(244 - 12 * radial)
            green = int(105 - 38 * radial)
            blue = int(91 - 23 * radial)

            ring_distance = abs(math.hypot(x, y) - 238)
            angle = (math.atan2(y, x) + math.tau) % math.tau
            in_gap = math.radians(292) < angle < math.radians(342)
            ring_alpha = (1.0 - smoothstep(29, 32, ring_distance)) * (0.0 if in_gap else 1.0)

            dot_distance = math.hypot(x - 184, y + 151)
            dot_alpha = 1.0 - smoothstep(43, 46, dot_distance)
            mark_alpha = max(ring_alpha, dot_alpha) * box_alpha

            alpha = int(255 * box_alpha)
            blend = mark_alpha
            red = int(red * (1 - blend) + 255 * blend)
            green = int(green * (1 - blend) + 255 * blend)
            blue = int(blue * (1 - blend) + 255 * blend)
            row.extend((red, green, blue, alpha))
        rows.append(bytes(row))

    raw = b"".join(rows)
    signature = b"\x89PNG\r\n\x1a\n"

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0)
    return signature + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


if __name__ == "__main__":
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(create_png())
    print(f"Generated {OUTPUT}")
