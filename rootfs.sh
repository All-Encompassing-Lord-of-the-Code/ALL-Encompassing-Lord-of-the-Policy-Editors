#!/bin/bash

/usr/share/vboot/bin/make_dev_ssd.sh -i /dev/mmcblk0 --remove_rootfs_verification --partitions 2
/usr/share/vboot/bin/make_dev_ssd.sh -i /dev/mmcblk0 --remove_rootfs_verification --partitions 4
/usr/share/vboot/bin/make_dev_ssd.sh -i /dev/mmcblk1 --remove_rootfs_verification --partitions 2
/usr/share/vboot/bin/make_dev_ssd.sh -i /dev/mmcblk1 --remove_rootfs_verification --partitions 4

