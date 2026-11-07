"""Export white SVG icons as lossless BLP2 textures with eight alpha mip levels."""

import io
import struct
from pathlib import Path

import cairosvg
from PIL import Image


TOOLS = Path(__file__).resolve().parent
MEDIA = TOOLS.parent / "QFXMinimapTools" / "Media"


def build(name):
    source = TOOLS / "minimap-icon-source" / f"{name}.svg"
    rendered = cairosvg.svg2png(url=str(source), output_width=1024, output_height=1024)
    coverage = Image.open(io.BytesIO(rendered)).convert("RGBA").getchannel("A")
    levels = []
    size = 128
    while size:
        alpha = coverage.resize((size, size), Image.Resampling.BOX)
        rgba = Image.new("RGBA", (size, size), (255, 255, 255, 0))
        rgba.putalpha(alpha)
        levels.append(rgba.tobytes("raw", "BGRA"))
        size //= 2
    offsets, lengths, position = [], [], 1172
    for level in levels:
        offsets.append(position)
        lengths.append(len(level))
        position += len(level)
    header = struct.pack("<4sIBBBBII", b"BLP2", 1, 3, 8, 8, 1, 128, 128)
    header += struct.pack("<16I", *(offsets + [0] * (16 - len(offsets))))
    header += struct.pack("<16I", *(lengths + [0] * (16 - len(lengths))))
    target = MEDIA / f"{name}_White.blp"
    target.write_bytes(header + bytes(1024) + b"".join(levels))
    print(f"{target.name}: {target.stat().st_size} bytes, 128..1 px, lossless alpha")


if __name__ == "__main__":
    for icon in ("Calendar", "Mail", "Hammer", "Magnifier"):
        build(icon)
