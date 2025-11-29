# -*- coding: utf-8 -*-

from pathlib import Path

DEPTH = 1024
BASE_DIR = Path(__file__).resolve().parent
BIN_FILE = BASE_DIR / "program.bin"
MIF_LOCAL = BASE_DIR / "program.mif"
MIF_ROM = (BASE_DIR / ".." / "rom_data.mif").resolve()


def load_words():
    data = BIN_FILE.read_bytes()
    words = [data[i:i + 4] for i in range(0, len(data), 4)]

    while len(words) < DEPTH:
        words.append(b"\x00\x00\x00\x00")

    return [int.from_bytes(w, "little") for w in words[:DEPTH]]


def write_mif(path: Path, values):
    with path.open("w", encoding="ascii") as f:
        f.write("WIDTH=32;\n")
        f.write(f"DEPTH={DEPTH};\n")
        f.write("ADDRESS_RADIX=UNS;\n")
        f.write("DATA_RADIX=HEX;\n\n")
        f.write("CONTENT BEGIN\n")

        start = 0
        current_val = values[0]

        for addr in range(1, DEPTH + 1):
            if addr < DEPTH and values[addr] == current_val:
                continue

            end = addr - 1

            if start == end:
                f.write(f"  {start} : {current_val:08X};\n")
            elif end == start + 1:
                f.write(f"  {start} : {current_val:08X};\n")
                f.write(f"  {end} : {current_val:08X};\n")
            else:
                f.write(f"  [{start}..{end}] : {current_val:08X};\n")

            if addr < DEPTH:
                start = addr
                current_val = values[addr]

        f.write("END;\n")


def main():
    values = load_words()
    for target in (MIF_LOCAL, MIF_ROM):
        write_mif(target, values)
        print(f"Generado {target}")


if __name__ == "__main__":
    main()
