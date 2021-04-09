
     _           .    .     _
    | \         | \  | \   / |
    | | __  ___ | |_ | | __| |
    | |/ / / __|| __|| |/ /| |
    |   < | /   | |_ |   < | |
    |_|\_\|_|    \__ |_|\_\|_|

    krtkl.com

    snickerdoodle Ubuntu 20.04 SD Card README
================================================================================

The BOOT partition of this SD card (where this file is located) must contain the
bootable components for the snickerdoodle and/or baseboard that the card will
be used on. The BOOT partition contains a set of folders; each with the
necessary boot components for a single system. To configure the SD card for the
corresponding system, copy the contents of the folder into the top level
of the BOOT partition.


Boot Components
================================

By default, this SD card image contains the Linux kernel, U-Boot script and a
couple of configuration files at the top level directory. These are files that
are normally used by all configurations, although some customization may be
desired to fit a specific application.

This un-configured SD card image does have the necessary bootloader or
devicetree at the top level directory to boot the system. Before attempting to
boot with this SD card, a boot.bin (bootloader) and devicetree.dtb (devicetree)
must be added. To use a pre-built configuration, simply copy the contents of
the directory to the top level of the BOOT partition. Below is an overview of
the top-level files that should be found in the BOOT partition before booting:

boot.bin*
devicetree.dtb*
system.bit**
uImage
uEnv.txt
config.txt
uboot.scr

* Needs to be copied before booting
** Optional, needs to be copied before booting


Prebuilt Configurations
================================

The BOOT partition of this SD card contains basic configurations for each
snickerdoodle variant and various baseboards. Each configuration is represented
by a directory containing the boot files. To boot a prebuilt configuration, copy
the contents of the directory to the top level of the BOOT partition and insert
the SD card into J6 on the snickerdoodle.


snickerdoodle Configuration
================================

The config.txt file is used by the Linux init scripts to configure users and
network settings. This file can be used to pre-configure the wireless access
point and/or station network settings before booting. It can also be used to
pre-configure user passwords in anticipation of remote login. See the config.txt
file for details on setting network and system configuration parameters.


Additional Configuration
================================

The uEnv.txt file contains additional configuration options such as setting the
ethernet MAC (hardware) address and specifying the boot arguments. This file
is read by U-Boot and can be used to specify a bitstream (system.bit by default)
to be loaded by U-Boot.


Runtime and Pre-Boot Configuration
================================

Various peripheral and boot settings are configured during runtime, or during
the boot process, by snickerdoodle's platform microcontroller. Examples include:
customizing LED behavior, antenna selection, and setting the boot mode. The
necessary 'spi-ctrl' application and an accompanying README can be found in the
/usr/local/bin directory. Visit krtkl.com/downloads for updates.


Devicetree and Linux Kernel Sources
================================

For reference, devicetree (e.g. .dts, .dtsi) and Linux kernel sources have been
included in the /usr/local/src directory.
