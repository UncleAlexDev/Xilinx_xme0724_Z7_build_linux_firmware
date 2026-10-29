KDIR ?= /lib/modules/$(shell uname -r)/build

all: esz7.ko

esz7.ko:
	$(MAKE) -C $(KDIR) M=$(PWD)

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

defconfig:
	echo "# " > .config
