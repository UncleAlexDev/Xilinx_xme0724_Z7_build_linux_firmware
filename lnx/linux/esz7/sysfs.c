// SPDX-License-Identifier: GPL-2.0-only
/*
 * \brief  sysfs operations for ESZ7 driver
 * \author Aleksey Lekhtin
 * \date   2025-09-25
 * \copyright Copyright 2024-2025 E-Service. Miass. Che.
 */

#define DEBUG 1
#define pr_fmt(fmt) KBUILD_MODNAME " " fmt

#include <linux/device.h>
#include <linux/seq_buf.h>
#include <linux/string.h>
#include <linux/sysfs.h>

#include "esz7.h"

static ssize_t event1_show(struct device *dev, struct device_attribute *attr,
			   char *buf)
{
	return 0;
}

static ssize_t event1_store(struct device *dev, struct device_attribute *attr,
			    const char *buf, size_t count)
{
	mutex_lock(&dev->mutex);
	sysfs_notify(&dev->kobj, NULL, "event1"); // EPOLLPRI
	mutex_unlock(&dev->mutex);
	return count;
}

static ssize_t event2_show(struct device *dev, struct device_attribute *attr,
			   char *buf)
{
	return 0;
}

static ssize_t event2_store(struct device *dev, struct device_attribute *attr,
			    const char *buf, size_t count)
{
	mutex_lock(&dev->mutex);
	sysfs_notify(&dev->kobj, NULL, "event2");
	mutex_unlock(&dev->mutex);
	return count;
}

static ssize_t event3_show(struct device *dev, struct device_attribute *attr,
			   char *buf)
{
	return 0;
}

static ssize_t event3_store(struct device *dev, struct device_attribute *attr,
			    const char *buf, size_t count)
{
	mutex_lock(&dev->mutex);
	sysfs_notify(&dev->kobj, NULL, "event3");
	mutex_unlock(&dev->mutex);
	return count;
}

static ssize_t event4_show(struct device *dev, struct device_attribute *attr,
			   char *buf)
{
	return 0;
}

static ssize_t event4_store(struct device *dev, struct device_attribute *attr,
			    const char *buf, size_t count)
{
	mutex_lock(&dev->mutex);
	sysfs_notify(&dev->kobj, NULL, "event4");
	mutex_unlock(&dev->mutex);
	return count;
}

static ssize_t name_show(struct device *dev, struct device_attribute *attr,
			 char *buf)
{
	ssize_t len;
	struct ESZ7 *esz7 = dev_get_drvdata(dev);

	mutex_lock(&dev->mutex);
	len = sysfs_emit(buf, "%s\n", esz7->of_name);
	mutex_unlock(&dev->mutex);
	return len;
}

static ssize_t version_show(struct device *dev, struct device_attribute *attr,
			    char *buf)
{
	ssize_t len;
	char *buffer;
	size_t buffersz;
	struct seq_buf seq_buffer;
	struct ESZ7 *esz7 = dev_get_drvdata(dev);

	mutex_lock(&dev->mutex);
	// sizeof(int) by 11 symbols for each
	buffersz = ARRAY_SIZE(esz7->of_interrupts) * 11;
	buffer = kzalloc(buffersz, GFP_KERNEL);
	if (buffer) {
		seq_buf_init(&seq_buffer, buffer, buffersz);
		for (int i = 0; i < ARRAY_SIZE(esz7->of_interrupts); i++)
			seq_buf_printf(&seq_buffer, "%d ",
				       esz7->of_interrupts[i]);
		seq_buffer.buffer[seq_buffer.len - 1] = '\0';
	}

	len = sysfs_emit(buf,
			 "Module: %s Ver: %s\n"
			 "Device: %s\n"
			 "ver: %s\n"
			 "compatible: %s\n"
			 "regs: 0x%08X\n"
			 "interrupts: %s\n",
			 MODULE_NAME, MODULE_VERS, esz7->of_name,
			 esz7->of_version, esz7->of_compatible, esz7->of_reg,
			 seq_buffer.buffer);
	kfree(buffer);
	mutex_unlock(&dev->mutex);
	return len;
}

static ssize_t compatible_show(struct device *dev,
			       struct device_attribute *attr, char *buf)
{
	ssize_t len;
	struct ESZ7 *esz7 = dev_get_drvdata(dev);

	mutex_lock(&dev->mutex);
	len = sysfs_emit(buf, "%s\n", esz7->of_compatible);
	mutex_unlock(&dev->mutex);
	return len;
}

static ssize_t reg_show(struct device *dev, struct device_attribute *attr,
			char *buf)
{
	ssize_t len;
	struct ESZ7 *esz7 = dev_get_drvdata(dev);

	mutex_lock(&dev->mutex);
	len = sysfs_emit(buf, "%08x\n", esz7->of_reg);
	mutex_unlock(&dev->mutex);
	return len;
}

static ssize_t interrupts_show(struct device *dev,
			       struct device_attribute *attr, char *buf)
{
	ssize_t len;
	char *buffer;
	size_t buffersz;
	struct seq_buf seq_buffer;
	struct ESZ7 *esz7 = dev_get_drvdata(dev);

	mutex_lock(&dev->mutex);
	// sizeof(int) by 11 symbols for each
	buffersz = ARRAY_SIZE(esz7->of_interrupts) * 11;
	buffer = kzalloc(buffersz, GFP_KERNEL);
	if (buffer) {
		seq_buf_init(&seq_buffer, buffer, buffersz);
		for (int i = 0; i < ARRAY_SIZE(esz7->of_interrupts); i++)
			seq_buf_printf(&seq_buffer, "%d ",
				       esz7->of_interrupts[i]);
		seq_buffer.buffer[seq_buffer.len - 1] = '\0';
	}

	len = sysfs_emit(buf, "%s\n", buffer);
	kfree(buffer);
	mutex_unlock(&dev->mutex);
	return len;
}

static ssize_t debuglevel_show(struct device *dev,
			       struct device_attribute *attr, char *buf)
{
	ssize_t len;

	mutex_lock(&dev->mutex);
	len = sysfs_emit(buf, "%d", debug_level);
	mutex_unlock(&dev->mutex);
	return len;
}

static ssize_t debuglevel_store(struct device *dev,
				struct device_attribute *attr, const char *buf,
				size_t count)
{
	int ret = kstrtouint(buf, 0, &debug_level);

	return ret ? ret : count;
}

// defines dev_attr_...
static DEVICE_ATTR_RW(event1);
static DEVICE_ATTR_RW(event2);
static DEVICE_ATTR_RW(event3);
static DEVICE_ATTR_RW(event4);
static DEVICE_ATTR_RO(name);
static DEVICE_ATTR_RO(version);
static DEVICE_ATTR_RO(reg);
static DEVICE_ATTR_RO(compatible);
static DEVICE_ATTR_RO(interrupts);
static DEVICE_ATTR_RW(debuglevel);

static struct attribute *esz7_attrs[] = {
	&dev_attr_event1.attr,
	&dev_attr_event2.attr,
	&dev_attr_event3.attr,
	&dev_attr_event4.attr,
	&dev_attr_name.attr,
	&dev_attr_version.attr,
	&dev_attr_compatible.attr,
	&dev_attr_reg.attr,
	&dev_attr_interrupts.attr,
	&dev_attr_debuglevel.attr,
	NULL,
};
ATTRIBUTE_GROUPS(esz7); // => esz7_groups

int esz7_create_sysfs_attributes(struct device *dev)
{
	int err;

	err = sysfs_create_groups(&dev->kobj, esz7_groups);
	if (err) {
		pr_info("sysfs_create_groups() failed. err: %d\n", err);
		return err;
	}
	return 0;
}

void esz7_remove_sysfs_attributes(struct device *dev)
{
	//DBG(1, "%s", "\n");
	sysfs_remove_groups(&dev->kobj, esz7_groups);
}
