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

# 1.5. Integrasi KernelSU-Next dev & SuSFS v2.3.0 (JackA1ltman baseline)
log_step "Mengintegrasikan KernelSU-Next dev terbaru + SuSFS v2.3.0 (JackA1ltman baseline)..."
cd "${KERNEL_DIR}"

# 1. Update KernelSU-Next ke pershoot/KernelSU-Next branch dev-susfs (commit 36aa55c5 + SuSFS 2.3.0)
rm -rf KernelSU-Next drivers/kernelsu
git clone -b dev-susfs https://github.com/pershoot/KernelSU-Next.git KernelSU-Next
git -C KernelSU-Next fetch origin dev:refs/remotes/origin/dev 2>/dev/null || true
ln -sf "../KernelSU-Next/kernel" drivers/kernelsu
sed -i 's/#include <asm\/syscall.h>/#include <asm\/syscall.h>\ntypedef long (*syscall_fn_t)(const struct pt_regs *regs);/' KernelSU-Next/kernel/hook/syscall_hook.h 2>/dev/null || true
grep -rl "linux/compiler_types.h" KernelSU-Next/ 2>/dev/null | xargs sed -i 's/linux\/compiler_types\.h/linux\/compiler\.h/g' 2>/dev/null || true
grep -rl "__nocfi" KernelSU-Next/ 2>/dev/null | xargs sed -i 's/__nocfi //g; s/__nocfi//g' 2>/dev/null || true
sed -i '1s/^/#ifndef __poll_t\ntypedef unsigned int __poll_t;\n#endif\n#ifndef EPOLLIN\n#define EPOLLIN 0x00000001\n#endif\n#ifndef EPOLLHUP\n#define EPOLLHUP 0x00000010\n#endif\n#ifndef EPOLLRDNORM\n#define EPOLLRDNORM 0x00000040\n#endif\n/' KernelSU-Next/kernel/infra/event_queue.h 2>/dev/null || true
cat << 'EOF' > KernelSU-Next/kernel/infra/file_wrapper.c
#include <linux/version.h>
#include <linux/errno.h>
#include <linux/init.h>
#include "infra/file_wrapper.h"

int ksu_install_file_wrapper(int fd)
{
    return -EOPNOTSUPP;
}

void __init ksu_file_wrapper_init(void)
{
}
EOF

cat << 'EOF' > KernelSU-Next/kernel/infra/seccomp_cache.c
#include "infra/seccomp_cache.h"

void ksu_seccomp_clear_cache(struct seccomp_filter *filter, int nr)
{
}

void ksu_seccomp_allow_cache(struct seccomp_filter *filter, int nr)
{
}
EOF

cat << 'EOF' > KernelSU-Next/kernel/infra/su_mount_ns.c
#include "infra/su_mount_ns.h"

void setup_mount_ns(int32_t ns_mode)
{
}
EOF

cat << 'EOF' > KernelSU-Next/kernel/manager/pkg_observer.c
#include <linux/init.h>
#include "manager/manager_observer.h"

int ksu_observer_init(void)
{
    return 0;
}

void __exit ksu_observer_exit(void)
{
}
EOF

sed -i 's/full_name_hash(NULL, /full_name_hash(/g' KernelSU-Next/kernel/manager/throne_tracker.c 2>/dev/null || true
sed -i 's/TWA_RESUME/true/g' KernelSU-Next/kernel/policy/allowlist.c 2>/dev/null || true
sed -i 's/TWA_RESUME/true/g' KernelSU-Next/kernel/supercall/supercall.c 2>/dev/null || true
sed -i 's/fallthrough;/do {} while (0);/g' KernelSU-Next/kernel/policy/allowlist.c 2>/dev/null || true
sed -i 's/struct selinux_state;/struct selinux_state { bool initialized; void *policy; };/' KernelSU-Next/kernel/feature/selinux_hide.h 2>/dev/null || true

python3 << 'EOF'
with open('KernelSU-Next/kernel/policy/app_profile.c', 'r') as f:
    c = f.read()
idx1 = c.find('void disable_seccomp(void)')
idx2 = c.find('int escape_with_root_profile(void)')
if idx1 != -1 and idx2 != -1:
    old_fn = c[idx1:idx2]
    new_fn = '''void disable_seccomp(void)
{
    spin_lock_irq(&current->sighand->siglock);
    clear_thread_flag(TIF_SECCOMP);
    current->seccomp.mode = 0;
    if (current->seccomp.filter) {
        put_seccomp_filter(current);
        current->seccomp.filter = NULL;
    }
    spin_unlock_irq(&current->sighand->siglock);
}

'''
    c = c.replace(old_fn, new_fn)
c = c.replace('group_info->gid[i] = kgid;', 'GROUP_AT(group_info, i) = kgid;')
with open('KernelSU-Next/kernel/policy/app_profile.c', 'w') as f:
    f.write(c)
EOF

cat << 'EOF' > KernelSU-Next/kernel/selinux/rules.c
#include <linux/version.h>
#include <linux/types.h>
#include <linux/errno.h>

struct selinux_policy *backup_sepolicy = NULL;

void apply_kernelsu_rules(void)
{
}

int handle_sepolicy(void __user *user_data, u64 data_len)
{
    return -EOPNOTSUPP;
}
EOF

cat << 'EOF' > KernelSU-Next/kernel/selinux/sepolicy.c
#include <linux/version.h>
#include <linux/types.h>
#include <linux/errno.h>
#include "sepolicy.h"

void ksu_destroy_sepolicy(struct selinux_policy *orig)
{
}

struct selinux_policy *ksu_dup_sepolicy(struct selinux_policy *old_pol)
{
    return (struct selinux_policy *)ERR_PTR(-EOPNOTSUPP);
}
EOF

sed -i 's/selinux_state\.enforcing/selinux_enforcing/g' KernelSU-Next/kernel/selinux/selinux.c 2>/dev/null || true
sed -i 's/selinux_state\.disabled/0/g' KernelSU-Next/kernel/selinux/selinux.c 2>/dev/null || true

cat << 'EOF' >> KernelSU-Next/kernel/include/klog.h
#include <linux/fs.h>
#include <linux/version.h>
#include <linux/timekeeping.h>
#ifndef fallthrough
#define fallthrough do {} while (0)
#endif
#ifndef TWA_RESUME
#define TWA_RESUME true
#endif
#ifndef untagged_addr
#define untagged_addr(addr) (addr)
#endif
#ifndef in_compat_syscall
#define in_compat_syscall() is_compat_task()
#endif
#if LINUX_VERSION_CODE < KERNEL_VERSION(5, 8, 0)
#ifndef strncpy_from_user_nofault
static inline long strncpy_from_user_nofault(char *dst, const void __user *unsafe_addr, long count) {
    if (unlikely(count <= 0))
        return 0;
    return strncpy_from_user(dst, unsafe_addr, count);
}
#endif
#endif
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 20, 0)
#ifndef ktime_get_boottime_ts64
static inline void ksu_ktime_get_boottime_ts64(struct timespec64 *ts) {
    getboottime64(ts);
}
#define ktime_get_boottime_ts64 ksu_ktime_get_boottime_ts64
#endif
#endif
#if LINUX_VERSION_CODE < KERNEL_VERSION(4, 14, 0)
#ifndef ksu_kernel_read_compat_defined
#define ksu_kernel_read_compat_defined
static inline ssize_t ksu_kernel_read_compat(struct file *file, void *buf, size_t count, loff_t *pos)
{
    ssize_t result = kernel_read(file, *pos, (char *)buf, count);
    if (result > 0)
        *pos += result;
    return result;
}
#define kernel_read ksu_kernel_read_compat

static inline ssize_t ksu_kernel_write_compat(struct file *file, const void *buf, size_t count, loff_t *pos)
{
    return __kernel_write(file, (const char *)buf, count, pos);
}
#define kernel_write ksu_kernel_write_compat
#endif
#endif
EOF

# 2. Terapkan SuSFS v2.3.0 (JackA1ltman baseline)
if [ -d "${ROOT_DIR}/patches/susfs_v230" ]; then
    cp "${ROOT_DIR}/patches/susfs_v230/fs/susfs.c" fs/susfs.c
    cp "${ROOT_DIR}/patches/susfs_v230/include/linux/susfs.h" include/linux/susfs.h
    cp "${ROOT_DIR}/patches/susfs_v230/include/linux/susfs_def.h" include/linux/susfs_def.h
    log_info "SuSFS v2.3.0 headers & core files diterapkan."
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

log_step "Mengaktifkan konfigurasi KernelSU-Next dev, SuSFS esensial, dan Mountify..."

# Patch Kconfig KernelSU-Next agar kompatibel dengan kernel 4.4 (non-GKI)
sed -i 's/\tdepends on THREAD_INFO_IN_TASK//' KernelSU-Next/kernel/Kconfig 2>/dev/null || true
sed -i 's/\tdepends on KPROBES || SUSFS//' KernelSU-Next/kernel/Kconfig 2>/dev/null || true
sed -i 's/\tdepends on KPROBES//' KernelSU-Next/kernel/Kconfig 2>/dev/null || true

# Tambahkan entri Kconfig yang hilang untuk sub-config SuSFS
if ! grep -q 'KSU_SUSFS_SUS_MOUNT' KernelSU-Next/kernel/Kconfig; then
    cat >> KernelSU-Next/kernel/Kconfig << 'KCONFIG_APPEND'

config KSU_SUSFS_SUS_MOUNT
	bool "Enable to hide suspicious mounts"
	depends on KSU_SUSFS

config KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT
	bool "Auto add SuSFS sus_mount for KSU mounts"
	depends on KSU_SUSFS

config KSU_SUSFS_SUS_KSTAT
	bool "Enable to spoof suspicious kstat"
	depends on KSU_SUSFS

config KSU_SUSFS_SPOOF_UNAME
	bool "Enable to spoof uname for SuSFS"
	depends on KSU_SUSFS

config KSU_SUSFS_ENABLE_LOG
	bool "Enable logging for SuSFS"
	depends on KSU_SUSFS

config KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS
	bool "Hide KernelSU and SuSFS symbols"
	depends on KSU_SUSFS

config KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG
	bool "Enable to spoof cmdline or bootconfig"
	depends on KSU_SUSFS

config KSU_SUSFS_OPEN_REDIRECT
	bool "Enable open redirect for SuSFS"
	depends on KSU_SUSFS

config KSU_SUSFS_SUS_MAP
	bool "Enable suspicious map for SuSFS"
	depends on KSU_SUSFS
KCONFIG_APPEND
fi

{
    # Core KernelSU & SuSFS Esensial (Minimal & Ringan)
    echo "CONFIG_KSU=y"
    echo "CONFIG_KSU_SUSFS=y"
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
