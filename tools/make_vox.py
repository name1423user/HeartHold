#!/usr/bin/env python3
"""Hearthold の仮でない自作ボクセル素材(.vox, MagicaVoxel 形式)を作る。

使い方: python3 tools/make_vox.py  (assets/voxel/*.vox を作り直す)
1ボクセル = ゲーム内 0.1 ブロック。z が上(MagicaVoxel の決まり)。
"""
import os
import struct

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "voxel")


class Model:
    def __init__(self, sx, sy, sz):
        self.size = (sx, sy, sz)
        self.voxels = {}
        self.palette = []

    def color(self, hex_color):
        hex_color = hex_color.lstrip("#")
        rgb = tuple(int(hex_color[i:i + 2], 16) for i in (0, 2, 4))
        if rgb not in self.palette:
            self.palette.append(rgb)
        return self.palette.index(rgb) + 1

    def box(self, x0, y0, z0, x1, y1, z1, hex_color):
        """両端を含む箱を塗る"""
        c = self.color(hex_color)
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                for z in range(z0, z1 + 1):
                    if 0 <= x < self.size[0] and 0 <= y < self.size[1] and 0 <= z < self.size[2]:
                        self.voxels[(x, y, z)] = c

    def clear(self, x0, y0, z0, x1, y1, z1):
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                for z in range(z0, z1 + 1):
                    self.voxels.pop((x, y, z), None)

    def save(self, name):
        xyzi = struct.pack("<i", len(self.voxels)) + b"".join(
            struct.pack("<BBBB", x, y, z, c) for (x, y, z), c in sorted(self.voxels.items()))
        palette = b"".join(struct.pack("<BBBB", r, g, b, 255) for r, g, b in self.palette)
        palette += b"\x00\x00\x00\xff" * (256 - len(self.palette))
        chunks = _chunk(b"SIZE", struct.pack("<iii", *self.size)) + _chunk(b"XYZI", xyzi) + _chunk(b"RGBA", palette)
        data = b"VOX " + struct.pack("<i", 150) + b"MAIN" + struct.pack("<ii", 0, len(chunks)) + chunks
        with open(os.path.join(OUT, name + ".vox"), "wb") as f:
            f.write(data)


def _chunk(chunk_id, content):
    return chunk_id + struct.pack("<ii", len(content), 0) + content


SKIN = "#e8c39e"
HAIR = "#6b4423"
TROUSERS = "#5a4632"
BOOTS = "#3b2a1a"


def person(shirt, hat=None, cape=None):
    m = Model(6, 4, 16)
    m.box(1, 1, 0, 2, 2, 1, BOOTS)
    m.box(3, 1, 0, 4, 2, 1, BOOTS)
    m.box(1, 1, 2, 4, 2, 6, TROUSERS)
    m.box(1, 1, 7, 4, 2, 11, shirt)
    m.box(0, 1, 7, 0, 2, 10, shirt)
    m.box(5, 1, 7, 5, 2, 10, shirt)
    m.box(0, 1, 6, 0, 2, 6, SKIN)
    m.box(5, 1, 6, 5, 2, 6, SKIN)
    m.box(1, 0, 12, 4, 3, 15, SKIN)
    m.box(1, 0, 15, 4, 3, 15, HAIR)
    m.box(1, 3, 12, 4, 3, 15, HAIR)
    m.box(2, 0, 13, 2, 0, 13, "#2a1d12")
    m.box(3, 0, 13, 3, 0, 13, "#2a1d12")
    if cape:
        m.box(1, 3, 3, 4, 3, 11, cape)
    if hat:
        m.box(0, 0, 15, 5, 3, 15, hat)
    return m


def goblin():
    m = Model(6, 4, 11)
    green = "#5f8a3a"
    m.box(1, 1, 0, 2, 2, 3, green)
    m.box(3, 1, 0, 4, 2, 3, green)
    m.box(1, 1, 4, 4, 2, 7, "#6b4f2e")
    m.box(0, 1, 4, 0, 2, 6, green)
    m.box(5, 1, 4, 5, 2, 6, green)
    m.box(1, 0, 8, 4, 3, 10, green)
    m.box(0, 1, 9, 0, 1, 10, green)
    m.box(5, 1, 9, 5, 1, 10, green)
    m.box(2, 0, 9, 2, 0, 9, "#d9302a")
    m.box(3, 0, 9, 3, 0, 9, "#d9302a")
    m.box(5, 0, 2, 5, 0, 8, "#8a8780")
    return m


def rabbit():
    m = Model(4, 6, 6)
    fur = "#cdb89a"
    m.box(0, 1, 0, 3, 4, 2, fur)
    m.box(1, 0, 2, 2, 1, 3, fur)
    m.box(1, 0, 4, 1, 0, 5, fur)
    m.box(2, 0, 4, 2, 0, 5, fur)
    m.box(1, 5, 2, 2, 5, 2, "#f2ede4")
    m.box(1, 0, 3, 1, 0, 3, "#2a1d12")
    return m


def house():
    m = Model(30, 30, 30)
    wall = "#efe2c4"
    beam = "#6e4b2a"
    roof = "#9c4a2f"
    stone = "#8a8780"
    m.box(0, 0, 0, 29, 29, 2, stone)
    m.box(1, 1, 3, 28, 28, 16, wall)
    m.clear(3, 3, 3, 26, 26, 16)
    for x in (1, 10, 19, 28):
        m.box(x, 1, 3, x, 1, 16, beam)
        m.box(x, 28, 3, x, 28, 16, beam)
    for y in (1, 10, 19, 28):
        m.box(1, y, 3, 1, y, 16, beam)
        m.box(28, y, 3, 28, y, 16, beam)
    m.box(1, 1, 16, 28, 1, 16, beam)
    m.box(1, 28, 16, 28, 28, 16, beam)
    m.box(12, 0, 3, 17, 1, 11, "#7a4e2a")
    m.box(4, 0, 8, 7, 1, 11, "#9cc3d9")
    m.box(22, 0, 8, 25, 1, 11, "#9cc3d9")
    for z in range(13):
        m.box(0, z, 17 + z, 29, z + 1, 17 + z, roof)
        m.box(0, 28 - z, 17 + z, 29, 29 - z, 17 + z, roof)
    m.box(0, 13, 29, 29, 16, 29, roof)
    m.box(21, 20, 22, 24, 23, 29, stone)
    return m


def storage():
    m = Model(30, 30, 20)
    plank = "#8a6a3d"
    dark = "#5a4428"
    m.box(0, 0, 0, 29, 29, 1, dark)
    for x in (0, 29):
        for y in (0, 29):
            m.box(x, y, 2, x, y, 14, dark)
    m.box(0, 0, 14, 29, 29, 15, plank)
    m.box(0, 29, 2, 29, 29, 13, plank)
    for (x, y) in ((4, 4), (12, 5), (5, 14), (18, 16), (20, 6)):
        m.box(x, y, 2, x + 5, y + 5, 7, "#a8763f")
        m.box(x, y, 7, x + 5, y + 5, 7, "#7a4e2a")
    m.box(6, 22, 2, 9, 25, 9, "#b07a45")
    return m


def workbench():
    m = Model(20, 10, 10)
    wood = "#9c7b52"
    m.box(0, 0, 6, 19, 9, 7, wood)
    for x in (1, 18):
        for y in (1, 8):
            m.box(x, y, 0, x, y, 5, "#6e4b2a")
    m.box(3, 3, 8, 6, 5, 8, "#8a8780")
    m.box(10, 2, 8, 10, 7, 8, "#6e4b2a")
    m.box(14, 4, 8, 17, 6, 9, "#a8763f")
    return m


def infirmary():
    m = house()
    m.palette = []
    recolored = Model(30, 30, 30)
    recolored.voxels = {}
    src_palette = house().palette
    for pos, c in m.voxels.items():
        hex_color = "#%02x%02x%02x" % src_palette[c - 1]
        if hex_color == "#9c4a2f":
            hex_color = "#5f7f5a"
        recolored.voxels[pos] = recolored.color(hex_color)
    # 薬草の看板(緑の葉)
    recolored.box(13, 0, 13, 16, 0, 15, "#efe2c4")
    recolored.box(14, 0, 13, 15, 0, 15, "#3f7a35")
    return recolored


def fence():
    m = Model(10, 10, 15)
    wood = "#6e4b2a"
    m.box(4, 4, 0, 5, 5, 14, wood)
    m.box(0, 4, 5, 9, 5, 6, "#8a6a3d")
    m.box(0, 4, 10, 9, 5, 11, "#8a6a3d")
    m.box(4, 0, 5, 5, 9, 6, "#8a6a3d")
    m.box(4, 0, 10, 5, 9, 11, "#8a6a3d")
    m.box(4, 4, 14, 5, 5, 14, "#a8763f")
    return m


def watchtower():
    m = Model(20, 20, 60)
    wood = "#7d5a37"
    dark = "#5a4428"
    for x in (1, 18):
        for y in (1, 18):
            m.box(x, y, 0, x, y, 47, dark)
    for z in (12, 24, 36):
        m.box(1, 1, z, 18, 1, z, wood)
        m.box(1, 18, z, 18, 18, z, wood)
        m.box(1, 1, z, 1, 18, z, wood)
        m.box(18, 1, z, 18, 18, z, wood)
    m.box(0, 0, 44, 19, 19, 45, wood)
    m.box(0, 0, 46, 19, 0, 49, wood)
    m.box(0, 19, 46, 19, 19, 49, wood)
    m.box(0, 0, 46, 0, 19, 49, wood)
    m.box(19, 0, 46, 19, 19, 49, wood)
    for z in range(8):
        m.box(z, z, 54 + z // 2, 19 - z, 19 - z, 54 + z // 2, "#9c4a2f")
    for x in (1, 18):
        for y in (1, 18):
            m.box(x, y, 50, x, y, 53, dark)
    return m


def ruin():
    m = Model(12, 12, 20)
    stone = "#9a958a"
    moss = "#6f8a4a"
    m.box(0, 0, 0, 11, 11, 1, stone)
    m.box(1, 1, 2, 3, 3, 17, stone)
    m.box(8, 1, 2, 10, 3, 10, stone)
    m.box(1, 8, 2, 3, 10, 6, stone)
    m.box(1, 1, 18, 7, 3, 19, stone)
    m.box(1, 1, 2, 3, 1, 5, moss)
    m.box(6, 7, 2, 8, 9, 3, stone)
    return m


def main():
    os.makedirs(OUT, exist_ok=True)
    shirts = {"gatherer": "#c9a14a", "builder": "#b5652b", "hunter": "#4f7a3a", "guard": "#45618c"}
    for job, shirt in shirts.items():
        hat = "#8a8780" if job == "guard" else None
        person(shirt, hat=hat).save("villager_" + job)
    person("#8c2f6b", hat="#d9a32b", cape="#5a1f45").save("chief")
    person("#7b4fa3", cape="#4a3166").save("applicant")
    goblin().save("goblin")
    rabbit().save("rabbit")
    house().save("house")
    storage().save("storage")
    workbench().save("workbench")
    infirmary().save("infirmary")
    fence().save("fence")
    watchtower().save("watchtower")
    ruin().save("ruin")


if __name__ == "__main__":
    main()
