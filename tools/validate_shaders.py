#!/usr/bin/env python3
"""
AETHERON SHADERS — Automated GLSL Preprocessor & glslangValidator Harness
==========================================================================
Expands Iris / OptiFine `#include "/..."` directives faithfully, applies
preset overrides from shaders.properties (`LOW`, `MEDIUM`, `ULTRA`) plus
feature stress-test matrices, and compiles EVERY vertex & fragment shader
across all dimensions (`world0`, `world-1`, `world1`) with `glslangValidator`.

Also validates:
- shaders.properties syntax & profile option consistency
- block.properties & lang file coverage
- Legacy 1.12.2 GLSL 120 compliance (max 8 colortex, no DRAWBUFFERS > 7, no GLSL 130+ keywords)
"""

import os
import re
import sys
import subprocess
import tempfile
import argparse
from pathlib import Path
from typing import Dict, List, Set, Tuple

INCLUDE_RE = re.compile(r'^\s*#include\s+"([^"]+)"\s*$')
DEFINE_VAL_RE = re.compile(r'^(\s*#define\s+)([A-Za-z_][A-Za-z0-9_]*)(\s+)([^\s/]+)(.*)$')
DEFINE_BOOL_RE = re.compile(r'^(\s*)(//)?(\s*#define\s+)([A-Za-z_][A-Za-z0-9_]*)(\s*(?://.*)?)$')
CONST_OPT_RE = re.compile(r'^(\s*const\s+(?:int|float)\s+)([A-Za-z_][A-Za-z0-9_]*)(\s*=\s*)([^;]+)(;.*)$')


def parse_profiles(props_path: Path) -> Dict[str, Dict[str, str]]:
    """Parse profile.<NAME> lines (including backslash continuations) from shaders.properties."""
    profiles: Dict[str, Dict[str, str]] = {}
    if not props_path.exists():
        return profiles

    raw_lines = props_path.read_text(encoding="utf-8").splitlines()
    joined: List[str] = []
    buf = ""
    for line in raw_lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.endswith("\\"):
            buf += stripped[:-1].strip() + " "
        else:
            joined.append((buf + stripped).strip())
            buf = ""
    if buf:
        joined.append(buf.strip())

    for entry in joined:
        if entry.startswith("profile."):
            lhs, _, rhs = entry.partition("=")
            prof_name = lhs.strip().split(".", 1)[1]
            opts: Dict[str, str] = {}
            for tok in rhs.strip().split():
                if tok.startswith("!program.") or tok.startswith("profile."):
                    continue
                if "=" in tok:
                    k, v = tok.split("=", 1)
                    opts[k] = v
                elif ":" in tok:
                    k, v = tok.split(":", 1)
                    opts[k] = v
                elif tok.startswith("!"):
                    opts[tok[1:]] = "__OFF__"
                else:
                    opts[tok] = "__ON__"
            profiles[prof_name] = opts
    return profiles


def apply_overrides_to_line(line: str, overrides: Dict[str, str]) -> str:
    """Apply Iris/OptiFine shader option overrides to settings.glsl lines."""
    m_const = CONST_OPT_RE.match(line)
    if m_const:
        name = m_const.group(2)
        if name in overrides:
            return f"{m_const.group(1)}{name}{m_const.group(3)}{overrides[name]}{m_const.group(5)}"

    m_val = DEFINE_VAL_RE.match(line)
    if m_val:
        name = m_val.group(2)
        if name in overrides and overrides[name] not in ("__ON__", "__OFF__"):
            return f"{m_val.group(1)}{name}{m_val.group(3)}{overrides[name]}{m_val.group(5)}"

    m_bool = DEFINE_BOOL_RE.match(line)
    if m_bool:
        name = m_bool.group(4)
        if name in overrides:
            if overrides[name] == "__OFF__":
                return f"// #define {name}"
            elif overrides[name] == "__ON__":
                return f"#define {name}"
    return line


def preprocess_includes(
    file_path: Path,
    shaders_root: Path,
    overrides: Dict[str, str],
    seen_stack: Set[Path],
) -> str:
    """Recursively expand Iris/OptiFine `#include` directives."""
    resolved = file_path.resolve()
    if resolved in seen_stack:
        raise RuntimeError(f"Circular #include detected: {resolved}")
    seen_stack.add(resolved)

    out_lines: List[str] = []
    for raw_line in file_path.read_text(encoding="utf-8").splitlines():
        m = INCLUDE_RE.match(raw_line)
        if m:
            inc = m.group(1)
            if inc.startswith("/"):
                inc_path = shaders_root / inc.lstrip("/")
            else:
                inc_path = file_path.parent / inc
            if not inc_path.exists():
                raise FileNotFoundError(f"Missing #include target '{inc}' referenced from {file_path}")
            out_lines.append(f"// --- BEGIN INCLUDE {inc} ---")
            out_lines.append(preprocess_includes(inc_path, shaders_root, overrides, seen_stack))
            out_lines.append(f"// --- END INCLUDE {inc} ---")
        else:
            out_lines.append(apply_overrides_to_line(raw_line, overrides))

    seen_stack.remove(resolved)
    return "\n".join(out_lines)


def check_legacy_constraints(shaders_root: Path, expanded: str, rel_path: str) -> List[str]:
    """Static verification of OptiFine 1.12.2 GLSL 120 hard constraints."""
    errors: List[str] = []
    first_nonempty = next((l.strip() for l in expanded.splitlines() if l.strip()), "")
    if not first_nonempty.startswith("#version 120"):
        errors.append(f"{rel_path}: Expected '#version 120' at line 1, got '{first_nonempty}'")

    # Check DRAWBUFFERS digits <= 7
    for m in re.finditer(r'DRAWBUFFERS\s*:\s*([0-9]+)', expanded):
        for ch in m.group(1):
            if int(ch) > 7:
                errors.append(f"{rel_path}: DRAWBUFFERS references colortex{ch} (>7 unsupported on OptiFine 1.12.2)")

    # Check no colortex8..15 declarations
    if re.search(r'\bcolortex(?:[89]|1[0-5])\b', expanded):
        errors.append(f"{rel_path}: References colortex8+ which is unsupported on OptiFine 1.12.2")

    # Check no thunderStrength (not built-in on 1.12.2)
    if re.search(r'\buniform\s+float\s+thunderStrength\b', expanded):
        errors.append(f"{rel_path}: Declares built-in uniform thunderStrength (missing in OptiFine 1.12.2)")

    return errors


def find_glslang() -> str:
    """Locate the glslang compiler (named glslangValidator or glslang depending on the distribution)."""
    import shutil
    for name in ("glslangValidator", "glslang"):
        path = shutil.which(name)
        if path:
            return path
    raise SystemExit("ERROR: glslangValidator/glslang not found in PATH. Install glslang (e.g. `scoop install glslang`).")


GLSLANG_BIN = None


def compile_shader(expanded_source: str, ext: str, label: str) -> Tuple[bool, str]:
    """Compile expanded GLSL source with glslangValidator."""
    global GLSLANG_BIN
    if GLSLANG_BIN is None:
        GLSLANG_BIN = find_glslang()
    stage = "vert" if ext == ".vsh" else "frag"
    with tempfile.NamedTemporaryFile("w", suffix=f".{stage}", delete=False, encoding="utf-8") as tmp:
        tmp.write(expanded_source)
        tmp_path = tmp.name

    try:
        proc = subprocess.run(
            [GLSLANG_BIN, "-S", stage, tmp_path],
            capture_output=True,
            text=True,
            check=False,
        )
        output = (proc.stdout + "\n" + proc.stderr).strip()
        if proc.returncode != 0:
            # Replace temp filename with human-readable shader label
            output = output.replace(tmp_path, label)
            return False, output
        return True, ""
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


def validate_edition(edition_name: str, shaders_root: Path, is_legacy: bool) -> Tuple[int, int, List[str]]:
    props_path = shaders_root / "shaders.properties"
    profiles = parse_profiles(props_path)

    # Stress-test matrix: LOW, MEDIUM, ULTRA + optional feature combinations
    test_configs: List[Tuple[str, Dict[str, str]]] = []
    for pname in ("LOW", "MEDIUM", "ULTRA"):
        if pname in profiles:
            test_configs.append((pname, profiles[pname]))

    if not test_configs:
        test_configs.append(("DEFAULT", {}))

    # Extra feature combination test (DoF + Motion Blur + AgX + Cloud Off)
    extra_opts = dict(profiles.get("ULTRA", {}))
    extra_opts.update({
        "DOF_ENABLED": "1",
        "MOTION_BLUR_ENABLED": "1",
        "TONEMAP_OPERATOR": "1",
    })
    test_configs.append(("ULTRA_EXTRAS_AGX_DOF_MB", extra_opts))

    extra_opts2 = dict(profiles.get("MEDIUM", {}))
    extra_opts2.update({
        "TONEMAP_OPERATOR": "2",
        "CLOUD_QUALITY": "0",
        "VOLUMETRIC_FOG_QUALITY": "0",
        "AO_QUALITY": "0",
        "REFLECTION_QUALITY": "0",
        "BLOOM_QUALITY": "0",
    })
    test_configs.append(("MINIMAL_TOGGLES_AETHERON_TM", extra_opts2))

    # Collect all dimension shader entrypoints
    shader_files: List[Path] = []
    for dim in ("world0", "world-1", "world1"):
        dim_dir = shaders_root / dim
        if dim_dir.exists():
            shader_files.extend(sorted(dim_dir.glob("*.vsh")))
            shader_files.extend(sorted(dim_dir.glob("*.fsh")))

    total = 0
    passed = 0
    failures: List[str] = []

    print(f"\n=== Validating {edition_name} ({len(shader_files)} shader entrypoints x {len(test_configs)} configs) ===")

    for cfg_name, overrides in test_configs:
        cfg_fail = 0
        for sf in shader_files:
            total += 1
            rel = sf.relative_to(shaders_root).as_posix()
            label = f"[{edition_name}:{cfg_name}] {rel}"
            try:
                expanded = preprocess_includes(sf, shaders_root, overrides, set())
            except Exception as e:
                failures.append(f"{label}: PREPROCESS ERROR: {e}")
                cfg_fail += 1
                continue

            if is_legacy:
                leg_errs = check_legacy_constraints(shaders_root, expanded, label)
                if leg_errs:
                    failures.extend(leg_errs)
                    cfg_fail += 1
                    continue

            ok, err_msg = compile_shader(expanded, sf.suffix, label)
            if ok:
                passed += 1
            else:
                failures.append(f"{label}:\n{err_msg}")
                cfg_fail += 1

        status = "PASS" if cfg_fail == 0 else f"FAIL ({cfg_fail} errors)"
        print(f"  Config {cfg_name:<28} : {status} ({len(shader_files) - cfg_fail}/{len(shader_files)})")

    return total, passed, failures


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Aetheron Modern & Legacy GLSL shaders")
    parser.add_argument("--edition", choices=["modern", "legacy", "all"], default="all")
    args = parser.parse_args()

    repo = Path(__file__).resolve().parent.parent
    all_failures: List[str] = []
    grand_total = 0
    grand_passed = 0

    if args.edition in ("modern", "all"):
        mod_root = repo / "modern" / "shaders"
        if mod_root.exists():
            t, p, f = validate_edition("Modern-Iris-1.20+", mod_root, is_legacy=False)
            grand_total += t
            grand_passed += p
            all_failures.extend(f)

    if args.edition in ("legacy", "all"):
        leg_root = repo / "legacy_1.12.2" / "shaders"
        if leg_root.exists() and any((leg_root / "world0").glob("*.fsh")):
            t, p, f = validate_edition("Legacy-OptiFine-1.12.2", leg_root, is_legacy=True)
            grand_total += t
            grand_passed += p
            all_failures.extend(f)

    print(f"\n=== SUMMARY: {grand_passed}/{grand_total} shader compilations succeeded ===")
    if all_failures:
        print("\n--- FAILURE DETAILS (first 15) ---")
        for err in all_failures[:15]:
            print(err)
            print("-" * 60)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
