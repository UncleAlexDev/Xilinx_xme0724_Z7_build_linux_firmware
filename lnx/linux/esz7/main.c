// SPDX-License-Identifier: GPL-2.0-only
/*
 *  \brief  ESZ7 driver
 *  \author Aleksey Lekhtin
 *  \date   2025-09-25
 *  \copyright Copyright 2024-2025 E-Service. Miass. Che.
 */

#include <linux/interrupt.h>
#include <linux/of.h>
#include <linux/of_device.h>
#include <linux/platform_device.h>
#include <linux/printk.h>
#include <linux/seq_buf.h>
#include <linux/signal.h>
#include <linux/version.h>

#include <linux/ktime.h>
#include <linux/rtc.h>

#include "esz7.h"

struct wdata_t {
	struct work_struct work;
	struct ESZ7 *esz7;
	int irq_idx;
};

static void work_handler(struct work_struct *w);

unsigned int debug_level;

void get_rtc_time(ktime_t *kt, struct rtc_time *t)
{
	*kt = ktime_get_real();
	*t = rtc_ktime_to_tm(*kt);
	//dev_info(dev, "%ptRs %s(): irq[%d]: %lu\n", &t, __func__, irq_idx, irqhw);
}

static irqreturn_t irq_handler(int irq_idx, void *dev_id)
{
	struct wdata_t *wdata;
	struct ESZ7 *esz7;
	struct device *dev;

	esz7 = (struct ESZ7 *)dev_id;
	dev = esz7->dev;

	wdata = kmalloc(sizeof(struct wdata_t), GFP_KERNEL);
	DBG(3, "irq_idx: %d, wdata: %p\n", irq_idx, wdata);
	if (wdata) {
		INIT_WORK(&wdata->work, work_handler);
		wdata->esz7 = esz7;
		wdata->irq_idx = irq_idx;
		DBG(3, "wdata->work: %p, wdata->irq_idx: %d\n", &wdata->work,
		    wdata->irq_idx);
		schedule_work(&wdata->work);
	}
	return IRQ_HANDLED;
}

static void work_handler(struct work_struct *work)
{
	struct wdata_t *wdata;
	struct ESZ7 *esz7;

	wdata = container_of(work, struct wdata_t, work);
	esz7 = wdata->esz7;
	DBG(3, "\nwdata: %p, work: %p, esz7: %p, irq_idx: %d\n", wdata,
	    &wdata->work, wdata->esz7, wdata->irq_idx);
	do {
		struct irq_desc *irqdsc;
		irq_hw_number_t irqhw;
		//unsigned int irqnum;

		irqdsc = irq_to_desc(wdata->irq_idx);
		//irqnum = irqdsc->irq_data.irq;
		irqhw = irqdsc->irq_data.hwirq;

		DBG(2, "irq[%d]: %lu\n", wdata->irq_idx, irqhw);

		// EPOLLPRI
		if (irqhw == 61)
			sysfs_notify(&esz7->dev->kobj, NULL, "event1");
		else if (irqhw == 62)
			sysfs_notify(&esz7->dev->kobj, NULL, "event2");
		else if (irqhw == 63)
			sysfs_notify(&esz7->dev->kobj, NULL, "event3");
		else if (irqhw == 64)
			sysfs_notify(&esz7->dev->kobj, NULL, "event4");

	} while (0);

	DBG(3, "free(%p)\n", wdata);
	kfree((void *)wdata);
}

static int driver_probe(struct platform_device *pdev)
{
	struct device *dev;
	struct ESZ7 *esz7;
	struct resource *res;
	void __iomem *iomem;
	int irq_idx, err, num;

	char *buffer;
	size_t buffersz;
	struct seq_buf seq_buffer;

	debug_level = 0;
	dev = &pdev->dev;
	dev_info(dev, "dev name:   %s\n", pdev->name);

	esz7 = devm_kcalloc(dev, 1, sizeof(*esz7), GFP_KERNEL);
	if (!esz7)
		return -ENOMEM;
	esz7->dev = dev;

	for (int i = 0; i < ARRAY_SIZE(esz7->irqs); i++)
		esz7->irqs[i] = -1;

	err = of_property_read_string(dev->of_node, "name", &esz7->of_name);
	dev_info(dev, "name:       %s\n", esz7->of_name);

	err = of_property_read_string(dev->of_node, "version",
				      &esz7->of_version);
	dev_info(dev, "version:    %s\n", esz7->of_version);

	err = of_property_read_string(dev->of_node, "compatible",
				      &esz7->of_compatible);
	dev_info(dev, "compatible: %s\n", esz7->of_compatible);

	err = of_property_read_u32(dev->of_node, "reg", &esz7->of_reg);
	dev_info(dev, "regs:       0x%08X\n", esz7->of_reg);

	num = of_property_count_u32_elems(dev->of_node, "interrupts");
	if (num > ARRAY_SIZE(esz7->of_interrupts))
		num = ARRAY_SIZE(esz7->of_interrupts);
	if (num > 0)
		err = of_property_read_u32_array(dev->of_node, "interrupts",
						 esz7->of_interrupts, num);

	buffersz = ARRAY_SIZE(esz7->of_interrupts) * 11;
	buffer = kzalloc(buffersz, GFP_KERNEL);
	if (buffer) {
		seq_buf_init(&seq_buffer, buffer, buffersz);
		for (int i = 0; i < ARRAY_SIZE(esz7->of_interrupts); i++)
			seq_buf_printf(&seq_buffer, "%d ",
				       esz7->of_interrupts[i]);
		seq_buffer.buffer[seq_buffer.len - 1] = '\0';
	}
	dev_info(dev, "interrupts: %s", buffer);
	kfree(buffer);

	num = platform_irq_count(pdev);
	dev_info(dev, "num of irq: %d (see /proc/interrupts)\n", num);

	for (int i = 0; i < num && i < ARRAY_SIZE(esz7->irqs); i++) {
		irq_idx = platform_get_irq(pdev, i);
		if (irq_idx < 0) {
			dev_info(
				dev,
				"ERR:  platform_get_irq(dev, %d) failed (%d)\n",
				i, irq_idx);
			continue;
		}
		dev_info(dev, "irq idx[%d]: %d\n", i, irq_idx);
		err = devm_request_irq(dev, irq_idx, irq_handler, 0, pdev->name,
				       esz7);
		if (err) {
			dev_info(
				dev,
				"ERR:  devm_request_irq(dev, %d) failed (%d)\n",
				irq_idx, err);
		} else {
			esz7->irqs[i] = irq_idx;
		}
	}

	platform_set_drvdata(pdev, esz7);

	res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
	iomem = devm_ioremap_resource(dev, res);
	if (IS_ERR(iomem)) {
		dev_info(dev, "devm_ioremap_resource() failed (%ld)\n",
			 PTR_ERR(iomem));
		return (int)PTR_ERR(iomem);
	}
	esz7->iomem = iomem;

	err = esz7_create_sysfs_attributes(dev);
	if (err)
		return err;

	return 0;
}

#if LINUX_VERSION_MAJOR == 6 && LINUX_VERSION_PATCHLEVEL == 1 && \
	LINUX_VERSION_SUBLEVEL == 0
static int driver_remove(struct platform_device *pdev)
#else
static void driver_remove(struct platform_device *pdev)
#endif
{
	struct device *dev = &pdev->dev;
	struct ESZ7 *esz7 = (struct ESZ7 *)platform_get_drvdata(pdev);

	dev_info(dev, "+++ removing driver...\n");

	DBG(1, "%s\n", "flush_scheduled_work()");
	flush_scheduled_work();

	esz7_remove_sysfs_attributes(dev);
	for (int i = 0; i < ARRAY_SIZE(esz7->irqs); i++) {
		if (esz7->irqs[i] < 0)
			continue;
		devm_free_irq(dev, esz7->irqs[i], NULL);
	}
	dev_info(dev, "+++ driver removed\n");

#if LINUX_VERSION_MAJOR == 6 && LINUX_VERSION_PATCHLEVEL == 1 && \
	LINUX_VERSION_SUBLEVEL == 0
	return 0;
#endif
}

static const struct of_device_id match_table[] = {
	{
		.compatible = "esz7,ads125h01",
	},
	{},
};

static struct platform_driver thedriver = {
	.probe = driver_probe,
	.remove = driver_remove,
	.driver = { .name = MODULE_NAME, .of_match_table = match_table },
};

module_platform_driver(thedriver);

MODULE_AUTHOR("AVL <lav@oil-service.com>");
MODULE_DESCRIPTION("ESZ7");
MODULE_LICENSE("GPL v2");
