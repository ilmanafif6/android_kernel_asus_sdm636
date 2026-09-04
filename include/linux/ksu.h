/* SPDX-License-Identifier: GPL-2.0 */
#ifndef __LINUX_KSU_H
#define __LINUX_KSU_H
static inline unsigned int get_ksu_state(void) { return 1; }
static inline unsigned int get_ksu_safe_mode_state(void) { return 0; }
#endif
