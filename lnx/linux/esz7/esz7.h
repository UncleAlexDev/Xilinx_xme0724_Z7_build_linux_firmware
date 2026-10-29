/* SPDX-License-Identifier: GPL-2.0-only */
/*
 *  \brief  ESZ7 driver
 *  \author Aleksey Lekhtin
 *  \date   2025-09-25
 *  \copyright Copyright 2024-2025 E-Service. Miass. Che.
 */

#ifndef ESZ7__H__
#define ESZ7__H__

#include <linux/dynamic_debug.h>
#include <linux/interrupt.h>
#include <linux/io.h>
#include <linux/of_device.h>
#include <linux/device.h>
#include <linux/platform_device.h>
#include <linux/spinlock.h>

#include <linux/ktime.h>
#include <linux/rtc.h>

#define MODULE_NAME "ESZ7"
#define MODULE_VERS "3.0.0 Dec 25 2025"

extern unsigned int debug_level;

#define DBG(LEVEL, FORMAT, ...)                                            \
	do {                                                               \
		if (debug_level >= (LEVEL)) {                              \
			char buf[128];                                     \
			ktime_t kt;                                        \
			struct rtc_time rtc;                               \
			get_rtc_time(&kt, &rtc);                           \
			snprintf(buf, sizeof(buf), FORMAT, __VA_ARGS__);   \
			pr_info("%lld %ptRs %s(): %s", kt, &rtc, __func__, \
				buf);                                      \
		}                                                          \
	} while (0)

void get_rtc_time(ktime_t *kt, struct rtc_time *t);
int esz7_create_sysfs_attributes(struct device *dev);
void esz7_remove_sysfs_attributes(struct device *dev);

struct ESZ7 {
	struct device *dev;
	void __iomem *iomem;
	void __iomem *addr_ctrl;
	void __iomem *addr_stat;
	void __iomem *addr_adc;
	const char *of_name;
	const char *of_version;
	const char *of_compatible;
	u32 of_reg;
	u32 of_interrupts[3*4];
	int irqs[4]; // index of IRQ cell in linux kernel
};

#endif //ESZ7__H__
