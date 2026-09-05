# AlphaCore Kernel for Asus ZenFone Max Pro M1 (X00TD)

Source kernel untuk Asus ZenFone Max Pro M1 (**X00TD** / **X00T**) dengan integrasi **KernelSU-Next (dev)** dan **SuSFS v2.3.0**.

---

## 📋 Spesifikasi Kernel
- **Kernel Name**: AlphaCore Kernel (HMP)
- **Maintainer**: ilmanafif6
- **Target Device**: Asus ZenFone Max Pro M1 (`X00TD` / `X00T`)
- **Chipset**: Qualcomm Snapdragon 636 (`sdm636`)
- **Kernel Base**: Linux 4.4.302 (CLO `LA.UM.9.2.r1-03700-SDMxx0.0`)
- **Default Branch**: `HMP`
- **Defconfig**: `vendor/asus/X00TD_defconfig` (CONFIG_LOCALVERSION="-AlphaCore-HMP")
- **Root Solution**: ReSukiSU `v4.2.0-rc1` (version code `35117`)
- **Root Hiding**: SuSFS `v2.3.0` (Multi-Manager & Full Inline Hooks)
- **Status**: Berfungsi (Built-in) + Permissive runtime SELinux injection
- **Compiler**: TRB Clang 17 / LLVM
- **Supported Android**: 9.0 (Pie) hingga 14.0

---

## 🚀 Build via GitHub Actions
Kompilasi berjalan di server GitHub Actions secara otomatis:

1. Buka tab **Actions** di repositori ini.
2. Pilih workflow **Build Asus X00TD Kernel**.
3. Klik tombol **Run workflow**:
   - Branch: `HMP`
   - Toolchain: `trb` (Clang 17)
   - Centang **Buat GitHub Release otomatis**.
4. Klik **Run workflow**.
5. File zip `AlphaCore-HMP-X00TD-<date>.zip` siap flash akan tersedia di tab **Releases** dan **Artifacts**.

---

## 📲 Cara Flash ke HP (X00TD)
1. Salin file `AlphaCore-*.zip` ke memori HP.
2. Reboot HP ke mode **Recovery** (TWRP / OrangeFox).
3. Pilih menu **Install** -> cari file zip kernel -> **Swipe to Flash**.
4. Setelah selesai, lakukan **Wipe Cache & Dalvik**.
5. Reboot System.
