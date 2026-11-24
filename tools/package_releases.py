#!/usr/bin/env python3
"""
AETHERON SHADERS — Release Packager
Builds drop-in Minecraft shaderpack .zip archives for:
  - dist/Aetheron-Modern-Iris-1.20+.zip
  - dist/Aetheron-Legacy-OptiFine-1.12.2.zip
"""

import zipfile
from pathlib import Path


def build_zip(source_dir: Path, out_zip: Path) -> int:
    out_zip.parent.mkdir(parents=True, exist_ok=True)
    count = 0
    with zipfile.ZipFile(out_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for path in sorted(source_dir.rglob("*")):
            if path.is_file():
                arcname = path.relative_to(source_dir).as_posix()
                zf.write(path, arcname)
                count += 1
    return count


def main() -> None:
    repo = Path(__file__).resolve().parent.parent
    dist = repo / "dist"

    m_cnt = build_zip(repo / "modern", dist / "Aetheron-Modern-Iris-1.20+.zip")
    l_cnt = build_zip(repo / "legacy_1.12.2", dist / "Aetheron-Legacy-OptiFine-1.12.2.zip")

    print(f"Packaged Modern Edition : dist/Aetheron-Modern-Iris-1.20+.zip ({m_cnt} files)")
    print(f"Packaged Legacy Edition : dist/Aetheron-Legacy-OptiFine-1.12.2.zip ({l_cnt} files)")


if __name__ == "__main__":
    main()
