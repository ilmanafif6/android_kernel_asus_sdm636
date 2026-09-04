/* SPDX-License-Identifier: GPL-2.0 */
#ifndef __LINUX_COMPILER_TYPES_H
#define __LINUX_COMPILER_TYPES_H
#include <linux/compiler.h>
#ifndef __nocfi
#define __nocfi
#endif
#ifndef fallthrough
#define fallthrough do {} while (0) /* fallthrough */
#endif
#ifndef TWA_RESUME
#define TWA_RESUME true
#endif
#endif
