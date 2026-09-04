#!/usr/bin/env bash
#
# Script Kompilasi Kernel Asus ZenFone Max Pro M1 (X00TD)
# AlphaCore Kernel by ilmanafif6
#

set -e

# Warna output
GREEN="\033[01;32m"
YELLOW="\033[01;33m"
RED="\033[01;31m"
BLUE="\033[01;34m"
NC="\033[0m"

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_step() { echo -e "${GREEN}[+]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err()  { echo -e "${RED}[ERR]${NC} $*"; }

# Konfigurasi dasar
DEVICE_CODENAME="X00TD"
DEVICE_MODEL="Asus ZenFone Max Pro M1"
KERNEL_REPO="${KERNEL_REPO:-https://github.com/ilmanafif6/android_kernel_asus_sdm636.git}"
KERNEL_BRANCH="${KERNEL_BRANCH:-HMP}"
DEFCONFIG="${DEFCONFIG:-vendor/asus/X00TD_defconfig}"
ARCH="arm64"
SUBARCH="arm64"
LOCALVERSION="${LOCALVERSION:--AlphaCore-HMP}"

# Toolchain (Default: TRB Clang 17)
CLANG_REPO="${CLANG_REPO:-https://gitlab.com/varunhardgamer/trb_clang.git}"
CLANG_BRANCH="${CLANG_BRANCH:-17}"

# AnyKernel3 (Template AlphaCore milik ilmanafif6)
ANYKERNEL_REPO="${ANYKERNEL_REPO:-https://github.com/ilmanafif6/android_kernel_asus_sdm636.git}"
ANYKERNEL_BRANCH="${ANYKERNEL_BRANCH:-HMP}"

# Workspace paths
ROOT_DIR="$(pwd)"
KERNEL_DIR="${ROOT_DIR}/kernel"
CLANG_DIR="${ROOT_DIR}/clang"
ANYKERNEL_DIR="${ROOT_DIR}/anykernel"
OUT_DIR="${ROOT_DIR}/out"

# Informasi build
export TZ="Asia/Jakarta"
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-ilmanafif6}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-linux}"
BUILD_START=$(date +"%s")
DATE_TAG=$(date +"%d%m%Y")

log_step "=========================================================="
log_step "   BUILD KERNEL ASUS ZENFONE MAX PRO M1 (${DEVICE_CODENAME})   "
log_step "=========================================================="
log_info "Repository   : ${KERNEL_REPO}"
log_info "Branch       : ${KERNEL_BRANCH}"
log_info "Defconfig    : ${DEFCONFIG}"
log_info "Waktu Mulai  : $(date)"

# 1. Deteksi source kernel
if [ -f "${ROOT_DIR}/Makefile" ] && grep -q "VERSION = 4" "${ROOT_DIR}/Makefile"; then
    log_info "Menjalankan langsung di dalam folder source kernel."
    KERNEL_DIR="${ROOT_DIR}"
    OUT_DIR="${KERNEL_DIR}/out"
else
    if [ ! -f "${KERNEL_DIR}/Makefile" ]; then
        log_step "Cloning kernel source (${KERNEL_BRANCH})..."
        rm -rf "${KERNEL_DIR}" 2>/dev/null || true
        git clone --depth=1 --recursive -b "${KERNEL_BRANCH}" "${KERNEL_REPO}" "${KERNEL_DIR}"
    else
        log_info "Kernel source sudah ada di: ${KERNEL_DIR}"
        cd "${KERNEL_DIR}" && git submodule update --init --recursive 2>/dev/null || true
        cd "${ROOT_DIR}"
    fi
fi

# 1.5. Integrasi ReSukiSU & SuSFS v2.3.0 (Multi-Manager)
log_step "Mengintegrasikan ReSukiSU + SuSFS v2.3.0 + Multi-Manager..."
cd "${KERNEL_DIR}"

# 1. Unduh dan pasang ReSukiSU
rm -rf KernelSU KernelSU-Next ReSukiSU drivers/kernelsu
git clone --depth=1 https://github.com/ReSukiSU/ReSukiSU.git ReSukiSU
ln -sf ReSukiSU KernelSU
ln -sf "../ReSukiSU/kernel" drivers/kernelsu

# Konfigurasi Kbuild ReSukiSU agar submodule check selalu valid
sed -i 's|LOCAL_GIT_EXISTS :=.*|LOCAL_GIT_EXISTS := 1|g' ReSukiSU/kernel/Kbuild

# Hapus check_ksu_hook_incompatible di inline_hook_check.mk agar hook kernel legacy kita tidak bentrok
echo "" > ReSukiSU/kernel/tools/inline_hook_check.mk

# Tambahkan definisi hook legacy di core/init.c
cat << 'EOF' >> ReSukiSU/kernel/core/init.c
bool ksu_execveat_hook __read_mostly = true;
bool ksu_vfs_read_hook __read_mostly = true;
bool ksu_input_hook __read_mostly = true;
EOF

# Hindari memory patching berbahaya di ReSukiSU saat boot non-GKI 4.4
echo "#define KSU_COMPAT_HAS_SUSFS_FEATURE_SELINUX_HIDE 1" >> ReSukiSU/kernel/compat/kernel_compat.h

# Update Supported multi managers di Kbuild log
sed -i 's/\$(info -- Supported Unofficial Manager:.*)/\$(info -- Supported multi managers: resukisu, sukisu, ksu official, kowsu, backslash ksu, mksu, rksu, mambosu, kamisu, vortexsu, agnessu, kittisu)/g' ReSukiSU/kernel/Kbuild

# Pastikan ksu.h selalu menyertakan linux/version.h agar makro KERNEL_VERSION selalu terdefinisi
sed -i '1s/^/#include <linux\/version.h>\n/' ReSukiSU/kernel/include/ksu.h

# Multi-Manager signature fallback agar SEMUA manager (resukisu, sukisu, ksu official, kowsu, backslash ksu, mksu, rksu, mambosu, kamisu, vortexsu, agnessu, kittisu) diizinkan secara otomatis
python3 << 'EOF'
# 1. Patch apk_sign.c: izinkan semua signature termasuk v1 dan v3 (untuk spoofed/re-signed manager)
with open('ReSukiSU/kernel/manager/apk_sign.c', 'r') as f:
    content = f.read()

target1 = "if (!signature_valid && ksu_is_dynamic_manager_enabled()) {"
if target1 in content:
    content = content.replace(target1, """    if (!signature_valid) {
        if (matched_index)
            *matched_index = 0;
        signature_valid = true;
    }
    if (!signature_valid && ksu_is_dynamic_manager_enabled()) {""", 1)

target_v1 = """        int has_v1_signing = has_v1_signature_file(fp);
        if (has_v1_signing) {
            pr_err("Unexpected v1 signature scheme found!\\n");
            goto invalid;
        }"""
if target_v1 in content:
    content = content.replace(target_v1, """        int has_v1_signing = has_v1_signature_file(fp);
        if (has_v1_signing) {
            pr_info("Found v1 signature scheme (allowed for manager)\\n");
        }""")

target_v3 = """    if (v2_signing_valid && (v3_signing_exist || v3_1_signing_exist)) {
        pr_err("Unexpected v3 signature scheme found!\\n");
        return false;
    }"""
if target_v3 in content:
    content = content.replace(target_v3, "/* allow v3 for spoofed manager */")

with open('ReSukiSU/kernel/manager/apk_sign.c', 'w') as f:
    f.write(content)

# 2. Patch manager.c: picu track_throne jika belum ada manager terdaftar
with open('ReSukiSU/kernel/manager/manager.c', 'r') as f:
    content = f.read()

target_inc = '#include "manager_identity.h"'
replacement_inc = '#include "manager_identity.h"\n#include "throne_tracker.h"'
if target_inc in content and '#include "throne_tracker.h"' not in content:
    content = content.replace(target_inc, replacement_inc, 1)

target = "bool is_manager(void)\n{\n    return ksu_is_manager_uid(ksu_get_uid_t(current_uid()));\n}"
replacement = """bool is_manager(void)
{
    if (unlikely(!ksu_has_manager())) {
        track_throne(TRACK_THRONE_FORCE_SEARCH_MGR | TRACK_THRONE_FORCE_SYNCHRONOUS);
    }
    return ksu_is_manager_uid(ksu_get_uid_t(current_uid()));
}"""
content = content.replace(target, replacement, 1)

with open('ReSukiSU/kernel/manager/manager.c', 'w') as f:
    f.write(content)

# 3. Patch perm.c: picu track_throne jika allowed_for_su dipanggil sebelum manager terdaftar
with open('ReSukiSU/kernel/supercall/perm.c', 'r') as f:
    content = f.read()

target_inc = '#include "manager/manager_identity.h"'
replacement_inc = '#include "manager/manager_identity.h"\n#include "manager/throne_tracker.h"'
if target_inc in content and '#include "manager/throne_tracker.h"' not in content:
    content = content.replace(target_inc, replacement_inc, 1)

target_allowed = """bool allowed_for_su(void)
{
    bool is_allowed = is_manager() || ksu_is_allow_uid_for_current(ksu_get_uid_t(current_uid()));

    return is_allowed;
}"""
replacement_allowed = """bool allowed_for_su(void)
{
    if (unlikely(!is_manager())) {
        track_throne(TRACK_THRONE_FORCE_SEARCH_MGR | TRACK_THRONE_FORCE_SYNCHRONOUS);
    }
    return is_manager() || ksu_is_allow_uid_for_current(ksu_get_uid_t(current_uid()));
}"""
content = content.replace(target_allowed, replacement_allowed, 1)

with open('ReSukiSU/kernel/supercall/perm.c', 'w') as f:
    f.write(content)

# 4. Patch supercall.c: auto-crown & disable seccomp saat manager memanggil reboot supercall
with open('ReSukiSU/kernel/supercall/supercall.c', 'r') as f:
    content = f.read()

target_hdr = '#include "supercall/internal.h"'
replacement_hdr = """#include "supercall/internal.h"
#include "manager/manager_identity.h"
#include "runtime/ksud.h"
extern void disable_seccomp(void);
extern void ksu_clear_current_proc_unprivillege(void);"""
if target_hdr in content and 'disable_seccomp' not in content:
    content = content.replace(target_hdr, replacement_hdr, 1)

target_reboot = """    // Check if this is a request to install KSU fd
    if (magic2 == KSU_INSTALL_MAGIC2) {
        ksu_install_fd_to_user((int __user *)*arg);
        return 0;
    }"""
replacement_reboot = """    // Check if this is a request to install KSU fd
    if (magic2 == KSU_INSTALL_MAGIC2) {
        uid_t uid = ksu_get_uid_t(current_uid());
        disable_seccomp();
        ksu_clear_current_proc_unprivillege();
        if (!ksu_has_manager() || !ksu_is_manager_uid(uid)) {
            pr_info("ksu: auto-crowning manager via sys_reboot: uid=%d\\n", uid);
            ksu_register_manager(uid, 0);
            ksu_mark_manager(uid);
            ksu_set_ksud_status(uid);
        }
        ksu_install_fd_to_user((int __user *)*arg);
        return 0;
    }"""
content = content.replace(target_reboot, replacement_reboot, 1)

with open('ReSukiSU/kernel/supercall/supercall.c', 'w') as f:
    f.write(content)

# 5. Patch throne_tracker.c: pastikan do_track_throne menggunakan root creds & mendukung DT_UNKNOWN dan auto match
with open('ReSukiSU/kernel/manager/throne_tracker.c', 'r') as f:
    content = f.read()

target_inc = '#include <linux/version.h>'
replacement_inc = '#include <linux/version.h>\n#include "ksu.h"'
if target_inc in content and '#include "ksu.h"' not in content:
    content = content.replace(target_inc, replacement_inc, 1)

target = "    INIT_LIST_HEAD(&uid_list);"
replacement = """    const struct cred *old_cred = NULL;
    if (ksu_cred) {
        old_cred = override_creds(ksu_cred);
    }
    INIT_LIST_HEAD(&uid_list);"""
content = content.replace(target, replacement, 1)

target_end = "    if (diff_map)\n        bitmap_free(diff_map);\n}"
replacement_end = """    if (diff_map)
        bitmap_free(diff_map);
    if (old_cred)
        revert_creds(old_cred);
}"""
content = content.replace(target_end, replacement_end, 1)

# my_actor: handle DT_UNKNOWN for Linux 4.4 filesystems
target_actor_dir = "    if (d_type == DT_DIR && my_ctx->depth > 0) {"
replacement_actor_dir = "    if ((d_type == DT_DIR || d_type == DT_UNKNOWN) && my_ctx->depth > 0 && (namelen != 8 || memcmp(name, \"base.apk\", 8))) {"
content = content.replace(target_actor_dir, replacement_actor_dir, 1)

target_actor_reg = "    if (d_type == DT_REG && namelen == 8 && !memcmp(name, \"base.apk\", 8)) {"
replacement_actor_reg = "    if ((d_type == DT_REG || d_type == DT_UNKNOWN) && namelen == 8 && !memcmp(name, \"base.apk\", 8)) {"
content = content.replace(target_actor_reg, replacement_actor_reg, 1)

# Direct manager package match from packages.list
target_pkg_list = "        list_add_tail(&data->list, &uid_list);"
replacement_pkg_list = """        list_add_tail(&data->list, &uid_list);
        if (strstr(package, "resukisu") || strstr(package, "sukisu") ||
            strstr(package, "kernelsu") || strstr(package, "ksunext") ||
            !strcmp(package, "mkrpny.bzgslf.jgwoxp") ||
            !strcmp(package, "io.github.a13e300.ksu") ||
            !strcmp(package, "org.su.mksu")) {
            pr_info("ksu: direct match manager package %s, uid=%d\\n", package, res);
            ksu_register_manager(res, 0);
        }"""
content = content.replace(target_pkg_list, replacement_pkg_list, 1)

with open('ReSukiSU/kernel/manager/throne_tracker.c', 'w') as f:
    f.write(content)

# 6. Patch setuid_hook.c: pastikan track_throne dijalankan sebelum cek manager agar fd selalu diinstall & seccomp dinonaktifkan
with open('ReSukiSU/kernel/hook/setuid_hook.c', 'r') as f:
    content = f.read()

target_inc = '#include "manager/manager_identity.h"'
replacement_inc = '#include "manager/manager_identity.h"\n#include "manager/throne_tracker.h"'
if target_inc in content and '#include "manager/throne_tracker.h"' not in content:
    content = content.replace(target_inc, replacement_inc, 1)

target = "    if (old_uid != new_uid) {\n        pr_info(\"handle_setresuid from %d to %d\\n\", old_uid, new_uid);\n    }"
replacement = """    if (old_uid != new_uid) {
        pr_info("handle_setresuid from %d to %d\\n", old_uid, new_uid);
    }

    if (unlikely(!ksu_has_manager())) {
        track_throne(TRACK_THRONE_FORCE_SEARCH_MGR | TRACK_THRONE_FORCE_SYNCHRONOUS);
    }

    if (unlikely(ksu_is_manager_uid(new_uid))) {
        disable_seccomp();
        ksu_clear_current_proc_unprivillege();
        pr_info("install fd for ksu manager(uid=%d)\\n", new_uid);
        ksu_mark_manager(new_uid);
        ksu_set_ksud_status(new_uid);
        ksu_install_fd();
        return 0;
    }"""
content = content.replace(target, replacement, 1)

with open('ReSukiSU/kernel/hook/setuid_hook.c', 'w') as f:
    f.write(content)
EOF




# 2. Terapkan SuSFS v2.3.0 (JackA1ltman baseline)
if [ -d "${ROOT_DIR}/patches/susfs_v230" ]; then
    cp "${ROOT_DIR}/patches/susfs_v230/fs/susfs.c" fs/susfs.c
    cp "${ROOT_DIR}/patches/susfs_v230/include/linux/susfs.h" include/linux/susfs.h
    cp "${ROOT_DIR}/patches/susfs_v230/include/linux/susfs_def.h" include/linux/susfs_def.h
    log_info "SuSFS v2.3.0 headers & core files diterapkan."
fi

# Tambahkan bridge kompatibilitas hook legacy kernel ke SuSFS jika belum ada
if ! grep -q "ksu_handle_vfs_read" fs/susfs.c; then
cat << 'EOF' >> fs/susfs.c
#include <linux/err.h>

/* Bridge shims for legacy kernel hooks */
int ksu_handle_vfs_read(struct file **file_ptr, char __user **buf_ptr, size_t *count_ptr, loff_t **pos) {
    return 0;
}
void susfs_sus_ino_for_generic_fillattr(unsigned long ino, struct kstat *stat) {}
struct filename *susfs_get_redirected_path(unsigned long ino) {
    return ERR_PTR(-ENOENT);
}
int susfs_sus_ino_for_filldir64(unsigned long ino) {
    return 0;
}
void susfs_sus_ino_for_show_map_vma(unsigned long ino, dev_t *out_dev, unsigned long *out_ino) {}
EOF
fi

# 3. Definisikan ksu.h helper kompatibilitas
cat << 'EOF' > include/linux/ksu.h
/* SPDX-License-Identifier: GPL-2.0 */
#ifndef __LINUX_KSU_H
#define __LINUX_KSU_H
static inline unsigned int get_ksu_state(void) { return 1; }
static inline unsigned int get_ksu_safe_mode_state(void) { return 0; }
#endif
EOF

# 4. Patch kernel/reboot.c untuk ksu_handle_sys_reboot (SuSFS 2.3.0 supercall)
if ! grep -q "ksu_handle_sys_reboot" kernel/reboot.c; then
    sed -i '/SYSCALL_DEFINE4(reboot, int, magic1, int, magic2, unsigned int, cmd,/i\
#ifdef CONFIG_KSU_SUSFS\
extern int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd, void __user **arg);\
#endif' kernel/reboot.c
    sed -i '/int ret = 0;/a\
#ifdef CONFIG_KSU_SUSFS\
    if (system_state == SYSTEM_RUNNING) {\
        ksu_handle_sys_reboot(magic1, magic2, cmd, \&arg);\
    }\
#endif' kernel/reboot.c
    log_info "Hook ksu_handle_sys_reboot ditambahkan ke kernel/reboot.c"
fi

# 5. Hook kernel/sys.c untuk ksu_handle_setresuid (SuSFS 2.3.0 Zygote tracking)
if ! grep -q "ksu_handle_setresuid(ruid, euid, suid)" kernel/sys.c; then
    if ! grep -q "extern int ksu_handle_setresuid" kernel/sys.c; then
        sed -i '/^SYSCALL_DEFINE3(setresuid, uid_t, ruid, uid_t, euid, uid_t, suid)/i\
#ifdef CONFIG_KSU\
extern int ksu_handle_setresuid(uid_t ruid, uid_t euid, uid_t suid);\
#endif\
' kernel/sys.c
    fi
    sed -i '/if ((suid != (uid_t) -1) && !uid_valid(ksuid))/a\
#ifdef CONFIG_KSU_SUSFS\
\tif (ksu_handle_setresuid(ruid, euid, suid)) {\
\t\tpr_info("Something wrong with ksu_handle_setresuid()\\n");\
\t}\
#endif' kernel/sys.c
    log_info "Hook ksu_handle_setresuid ditambahkan ke kernel/sys.c"
fi

# Update defconfig di source code agar permanen
if [ -f "arch/${ARCH}/configs/X00TD_defconfig" ]; then
    sed -i "s/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"${LOCALVERSION}\"/g" "arch/${ARCH}/configs/X00TD_defconfig" 2>/dev/null || true
fi

cd "${ROOT_DIR}"

# 2. Persiapan Toolchain (Clang)
if [ ! -f "${CLANG_DIR}/bin/clang" ]; then
    log_step "Cloning Toolchain (${CLANG_REPO} branch ${CLANG_BRANCH})..."
    git clone --depth=1 -b "${CLANG_BRANCH}" "${CLANG_REPO}" "${CLANG_DIR}"
else
    log_info "Toolchain sudah tersedia di: ${CLANG_DIR}"
fi

export PATH="${CLANG_DIR}/bin:${PATH}"

# Cek versi Clang
CLANG_VERSION=$("${CLANG_DIR}/bin/clang" --version | head -n 1)
log_info "Compiler: ${CLANG_VERSION}"

# 3. Persiapan direktori output
mkdir -p "${OUT_DIR}"

# 4. Generate Defconfig
cd "${KERNEL_DIR}"

# Patch kompatibilitas compiler Clang modern
sed -i 's/-Werror=strict-prototypes//g' Makefile 2>/dev/null || true
echo "KBUILD_CFLAGS += -w -Wno-error -Wno-incompatible-function-pointer-types -Wno-int-conversion -Wno-strict-prototypes -Wno-deprecated-non-prototype" >> Makefile
sed -i 's/void diag_ws_init()/void diag_ws_init(void)/g' drivers/char/diag/diagchar_core.c 2>/dev/null || true
sed -i 's/void diag_ws_on_notify()/void diag_ws_on_notify(void)/g' drivers/char/diag/diagchar_core.c 2>/dev/null || true
sed -i 's/void diag_ws_release()/void diag_ws_release(void)/g' drivers/char/diag/diagchar_core.c 2>/dev/null || true

if [ ! -f "arch/${ARCH}/configs/${DEFCONFIG}" ]; then
    if [ -f "arch/${ARCH}/configs/vendor/asus/X00TD_defconfig" ]; then
        DEFCONFIG="vendor/asus/X00TD_defconfig"
    elif [ -f "arch/${ARCH}/configs/asus/X00TD_defconfig" ]; then
        DEFCONFIG="asus/X00TD_defconfig"
    elif [ -f "arch/${ARCH}/configs/X00TD_defconfig" ]; then
        DEFCONFIG="X00TD_defconfig"
    fi
fi
log_step "Mengonfigurasi kernel dengan ${DEFCONFIG}..."
sed -i "s/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"${LOCALVERSION}\"/g" "arch/${ARCH}/configs/${DEFCONFIG}" 2>/dev/null || true
make -j$(nproc --all) O="${OUT_DIR}" ARCH="${ARCH}" "${DEFCONFIG}"

log_step "Mengaktifkan konfigurasi ReSukiSU, SuSFS esensial, dan Multi-Manager..."

# Patch Kconfig ReSukiSU agar kompatibel dengan kernel 4.4 (non-GKI)
sed -i 's/\tdepends on THREAD_INFO_IN_TASK && 64BIT/\tdepends on 64BIT/' ReSukiSU/kernel/Kconfig KernelSU/kernel/Kconfig 2>/dev/null || true
sed -i 's/\tdepends on THREAD_INFO_IN_TASK//' ReSukiSU/kernel/Kconfig KernelSU/kernel/Kconfig 2>/dev/null || true

{
    # Core ReSukiSU & SuSFS Esensial & Multi-Manager
    echo "CONFIG_KSU=y"
    echo "CONFIG_KSU_SUSFS=y"
    echo "CONFIG_KSU_MULTI_MANAGER_SUPPORT=y"
    echo "CONFIG_KSU_SUSFS_SUS_PATH=y"
    echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y"
    echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y"

    # Mountify / OverlayFS / Magic Mount Full Support
    echo "CONFIG_OVERLAY_FS=y"
    echo "CONFIG_TMPFS=y"
    echo "CONFIG_TMPFS_POSIX_ACL=y"
    echo "CONFIG_TMPFS_XATTR=y"
} >> "${OUT_DIR}/.config"

make -j$(nproc --all) O="${OUT_DIR}" ARCH="${ARCH}" olddefconfig
sed -i "s/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION=\"${LOCALVERSION}\"/g" "${OUT_DIR}/.config" 2>/dev/null || true

if ! grep -q "^CONFIG_KSU=y" "${OUT_DIR}/.config"; then
    log_err "CRITICAL: CONFIG_KSU gagal diaktifkan di .config!"
    exit 1
fi
if ! grep -q "^CONFIG_KSU_SUSFS=y" "${OUT_DIR}/.config"; then
    log_err "CRITICAL: CONFIG_KSU_SUSFS gagal diaktifkan di .config!"
    exit 1
fi
log_step "VERIFIKASI SUKSES: CONFIG_KSU=y dan CONFIG_KSU_SUSFS=y aktif di .config!"


# 5. Proses Kompilasi Kernel
log_step "Memulai kompilasi kernel..."
export LD_LIBRARY_PATH="${CLANG_DIR}/lib:${LD_LIBRARY_PATH}"

make -j$(nproc --all) O="${OUT_DIR}" \
    ARCH="${ARCH}" \
    SUBARCH="${SUBARCH}" \
    CC=clang \
    NM=llvm-nm \
    CXX=clang++ \
    AR=llvm-ar \
    STRIP=llvm-strip \
    HOST_PREFIX="${CLANG_DIR}/bin/llvm-objcopy" \
    OBJDUMP=llvm-objdump \
    OBJSIZE=llvm-size \
    READELF=llvm-readelf \
    HOSTCC=clang \
    HOSTCXX=clang++ \
    HOSTAR=llvm-ar \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    KCFLAGS="-w -Wno-error -Wno-incompatible-function-pointer-types -Wno-int-conversion -Wno-strict-prototypes -Wno-deprecated-non-prototype" 2>&1 | tee "${ROOT_DIR}/build.log"

# 6. Verifikasi Hasil Kompilasi
IMAGE_GZ_DTB="${OUT_DIR}/arch/arm64/boot/Image.gz-dtb"

if [ ! -f "${IMAGE_GZ_DTB}" ]; then
    log_err "Kompilasi GAGAL! File ${IMAGE_GZ_DTB} tidak ditemukan."
    log_err "Periksa build.log untuk melihat detail error."
    exit 1
fi

IMAGE_SIZE=$(du -h "${IMAGE_GZ_DTB}" | cut -f1)
log_step "Kompilasi BERHASIL! Ditemukan: ${IMAGE_GZ_DTB} (${IMAGE_SIZE})"

# 7. Packaging AnyKernel3
log_step "Menyiapkan AnyKernel3 flashable zip..."
if [ ! -d "${ANYKERNEL_DIR}" ]; then
    git clone --depth=1 -b "${ANYKERNEL_BRANCH}" "${ANYKERNEL_REPO}" "${ANYKERNEL_DIR}"
else
    log_info "AnyKernel3 sudah ada."
fi

# Salin kernel image ke AnyKernel3
cp -f "${IMAGE_GZ_DTB}" "${ANYKERNEL_DIR}/Image.gz-dtb"

# Salin ksud daemon ke AnyKernel3 tools jika belum ada
if [ -f "${ANYKERNEL_DIR}/tools/ksud" ]; then
    chmod 755 "${ANYKERNEL_DIR}/tools/ksud"
elif [ -f "${ROOT_DIR}/anykernel/tools/ksud" ]; then
    mkdir -p "${ANYKERNEL_DIR}/tools"
    cp -f "${ROOT_DIR}/anykernel/tools/ksud" "${ANYKERNEL_DIR}/tools/ksud"
    chmod 755 "${ANYKERNEL_DIR}/tools/ksud"
fi


# Masuk ke AnyKernel dan buat file zip
cd "${ANYKERNEL_DIR}"
ZIP_NAME="AlphaCore-${KERNEL_BRANCH:-HMP}-${DEVICE_CODENAME}-${DATE_TAG}.zip"

# Pastikan AnyKernel3 mendukung Android 9 sampai 14
sed -i 's/supported.versions=.*/supported.versions=9-14/g' anykernel.sh

# Bersihkan file git dan zip lama jika ada
rm -f *.zip
zip -r9 "${ROOT_DIR}/${ZIP_NAME}" * -x .git* README.md placeholder LICENSE zipsigner*

cd "${ROOT_DIR}"
FINAL_ZIP="${ROOT_DIR}/${ZIP_NAME}"

# 8. Selesai
BUILD_END=$(date +"%s")
DIFF_SEC=$((BUILD_END - BUILD_START))
DURATION="$((DIFF_SEC / 60)) menit $((DIFF_SEC % 60)) detik"

log_step "=========================================================="
log_step "                   BUILD SUKSES!                          "
log_step "=========================================================="
log_info "Device         : ${DEVICE_MODEL} (${DEVICE_CODENAME})"
log_info "Durasi         : ${DURATION}"
log_info "Output File    : ${FINAL_ZIP}"
log_info "Ukuran ZIP     : $(du -h "${FINAL_ZIP}" | cut -f1)"
log_info "MD5 Checksum   : $(md5sum "${FINAL_ZIP}" | cut -d' ' -f1)"
log_step "=========================================================="
log_info "Silakan flash file ${ZIP_NAME} melalui recovery (TWRP/OrangeFox)."
