#!/bin/bash

#A better policy Editor
# fr jmoney46 68 240 67

if [ $(id -u) -ne 0 ]; then
    echo "Run this script as root (sudo su)"
    exit
fi


clear

echo "  
      WELCOME TO THE ALL ENCOMPASSING LORD OF THE POLICY EDITORS!
      A policy tool for all chrome os versions."

ensure_rw() {
    local test_file="/usr/bin/.rwtest.$$"
    local tool="/usr/share/vboot/bin/make_dev_ssd.sh"
    local disks=(/dev/mmcblk0 /dev/mmcblk1)
    local found=0
    local failed=0

    if (umask 077; : > "$test_file") 2>/dev/null; then
        rm -f "$test_file"
        return 0
    fi

    echo "Root filesystem is read-only."

    if [[ ! -x "$tool" ]]; then
        log "ERROR: make_dev_ssd.sh not found or not executable."
        return 1
    fi

    echo "Attempting to remove rootfs verification..."
    
    for disk in "${disks[@]}"; do
        [[ -b "$disk" ]] || continue

        found=1
        echo "Processing $disk..."

        for partition in 2 4; do
            echo "Updating $disk partition $partition..."

            if ! "$tool" -i "$disk" \
                --remove_rootfs_verification \
                --partitions "$partition"; then

                echo "ERROR: Failed on $disk partition $partition."
                failed=1
            fi
        done
    done

    if (( ! found )); then
        log "ERROR: No supported storage devices found."
        return 1
    fi

    if (( failed )); then
        log "ERROR: Rootfs verification changes were unsuccessful."
        return 1
    fi

    echo "Rootfs verification changes completed."
    echo "Reboot and rerun to apply changes."

    exit 0
}
ensure_rw()
