"""Export four true SVG stroke weights per icon into a padded BLP2 strip."""

import io
import struct
import xml.etree.ElementTree as ET
from pathlib import Path

import cairosvg
from PIL import Image


TOOLS = Path(__file__).resolve().parent
MEDIA = TOOLS.parent / "QFXMinimapTools" / "Media"
WEIGHTS = (2.0, 2.5, 3.0, 3.5)
CELL_SIZE = 128
GUTTER = 8


def render_alpha(name, weight, size):
    source = TOOLS / "minimap-icon-source" / f"{name}.svg"
    svg = ET.fromstring(source.read_bytes())
    svg.set("stroke-width", str(weight))
    rendered = cairosvg.svg2png(bytestring=ET.tostring(svg), output_width=1024, output_height=1024)
    coverage = Image.open(io.BytesIO(rendered)).convert("RGBA").getchannel("A")
    return coverage.resize((size, size), Image.Resampling.BOX)


def build(name):
    width, height = CELL_SIZE * len(WEIGHTS), CELL_SIZE
    coverage = Image.new("L", (width, height))
    for index, weight in enumerate(WEIGHTS):
        alpha = render_alpha(name, weight, CELL_SIZE - GUTTER * 2)
        coverage.paste(alpha, (index * CELL_SIZE + GUTTER, GUTTER))
    levels = []
    mip_width, mip_height = width, height
    while mip_height:
        alpha = coverage.resize((mip_width, mip_height), Image.Resampling.BOX)
        rgba = Image.new("RGBA", (mip_width, mip_height), (255, 255, 255, 0))
        rgba.putalpha(alpha)
        levels.append(rgba.tobytes("raw", "BGRA"))
        mip_width //= 2
        mip_height //= 2
    offsets, lengths, position = [], [], 1172
    for level in levels:
        offsets.append(position)
        lengths.append(len(level))
        position += len(level)
    header = struct.pack("<4sIBBBBII", b"BLP2", 1, 3, 8, 8, 1, width, height)
    header += struct.pack("<16I", *(offsets + [0] * (16 - len(offsets))))
    header += struct.pack("<16I", *(lengths + [0] * (16 - len(lengths))))
    target = MEDIA / f"{name}_Weights.blp"
    target.write_bytes(header + bytes(1024) + b"".join(levels))
    print(f"{target.name}: {target.stat().st_size} bytes, {width}x{height}, four weights, eight mip levels")


if __name__ == "__main__":
    for icon in ("Calendar", "Mail", "Hammer", "Magnifier"):
        build(icon)
