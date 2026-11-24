# Installation & Setup Guide

---

## Option A: Modern Edition (Minecraft 1.20.x / 1.21.x+ with Iris & Sodium)

### Prerequisites
- Minecraft **1.20.1 – 1.21.x**
- **Iris Shaders** (latest stable release) + **Sodium** (bundled with Iris Installer or installed via Fabric / NeoForge)
- Up-to-date GPU drivers (NVIDIA Game Ready / Studio Driver recommended for RTX 50-series)

### Installation Steps
1. Locate the packaged shader archive `dist/Aetheron-Modern-Iris-1.20+.zip` (or zip the contents of the `modern/` folder so `shaders/` sits at the archive root).
2. Launch Minecraft with Iris + Sodium.
3. Navigate to **Options → Video Settings → Shader Packs → Open Shader Pack Folder**.
4. Copy `Aetheron-Modern-Iris-1.20+.zip` into the `shaderpacks/` folder.
5. Select **Aetheron-Modern-Iris-1.20+** in the list and click **Apply**.
6. Click **Shader Pack Settings...** and choose your desired preset (**Low**, **Medium**, or **Ultra**).

### Recommended Modern Video Settings (RTX 5070 + 9800X3D)
- **Preset**: `Ultra (RTX Next-Gen)`
- **Render Distance**: `16–24 chunks`
- **Simulation Distance**: `12–16 chunks`
- **Graphics**: `Fancy` or `Fabulous`
- **Smooth Lighting**: `On`
- **Clouds**: Automatically managed by Aetheron (`clouds = off` in `shaders.properties`)
- **Biome Blend**: `5×5` or `7×7` for smooth biome transitions

---

## Option B: Legacy Edition (Minecraft 1.12.2 with OptiFine)

### Prerequisites
- Minecraft **1.12.2**
- **OptiFine 1.12.2 HD U G5** (or **G6 pre1+**)

### Installation Steps
1. Locate `dist/Aetheron-Legacy-OptiFine-1.12.2.zip` (or zip the contents of `legacy_1.12.2/` so `shaders/` sits at the archive root).
2. Launch Minecraft 1.12.2 with OptiFine.
3. Navigate to **Options → Video Settings → Shaders → Shaders Folder**.
4. Copy `Aetheron-Legacy-OptiFine-1.12.2.zip` into the `shaderpacks/` folder.
5. Select **Aetheron-Legacy-OptiFine-1.12.2** in the Shaders menu.
6. Ensure OptiFine's right-side shader multipliers are left at default:
   - **Render Quality**: `1.0x`
   - **Shadow Quality**: `1.0x`
   - **Old Lighting**: `Default`
   - **Old Hand Light**: `Default`
7. Open **Shader Options...** and select **Low**, **Medium**, or **Ultra**.

### Recommended 1.12.2 Video Settings
- **Fast Render**: `OFF` (required by OptiFine shaders)
- **Antialiasing / Anisotropic Filtering (OptiFine)**: `OFF` (Aetheron provides native YCoCg TAA)
- **Smooth Lighting**: `Maximum (100%)`
- **Render Distance**: `14–18 chunks` (prevents 1.12.2 single-threaded CPU bottlenecks)

---

## Building Packages From Source

If you modify GLSL files inside `modern/` or `legacy_1.12.2/`, you can validate compilation and rebuild both `.zip` archives with:

```bash
python3 tools/validate_shaders.py --edition all
python3 tools/package_releases.py
```
