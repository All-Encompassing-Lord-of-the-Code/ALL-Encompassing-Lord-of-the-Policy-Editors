#!/bin/bash
#A better policy Editor
# fr jmoney46 68 240 67

get_largest_cros_blockdev() {
    local largest size dev_name tmp_size remo
    size=0
    for blockdev in /sys/block/*; do
        dev_name="${blockdev##*/}"
        echo "$dev_name" | grep -q '^\(loop\|ram\)' && continue
        tmp_size=$(cat "$blockdev"/size)
        remo=$(cat "$blockdev"/removable)
        if [ "$tmp_size" -gt "$size" ] && [ "${remo:-0}" -eq 0 ]; then
            case "$(doas sfdisk -l -o name "/dev/$dev_name" 2>/dev/null)" in
                *STATE*KERN-A*ROOT-A*KERN-B*ROOT-B*)
                    largest="/dev/$dev_name"
                    size="$tmp_size"
                    ;;
            esac
        fi
    done
    echo "$largest"
}

traps() {
    set +e
    trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
    trap 'echo \"${last_command}\" command failed with exit code $? - press a key to exit.' EXIT
    trap '' INT
}

swallow_stdin() {
    while read -t 0 notused; do
        read input
    done
}

cd /

if [ $(id -u) -ne 0 ]; then
    echo "Run this script as root (sudo su)"
    exit
fi


clear

echo "  
      WELCOME TO THE ALL ENCOMPASSING LORD OF THE POLICY EDITORS!
      A policy tool for all chrome os versions."

main_install_menu() {
    traps
    echo "Select a policy option:
    1) Pollen (r131 and below)
    2) Lilac (TBA)
    3) Modmium (TBA)
"

    swallow_stdin
    read -r -p "Pick an option 1- 3, q to quit> " choise
    case "$choise" in
    
    1) runjon policy_pollen_copy ;;
    q) exit ;;

    *) echo && echo "Invalid option." && echo ;;
    esac

}

policy_pollen_copy() {
    clear
    echo "You chose 'Pollen'"
    cd /etc
    mkdir opt
    cd opt
    mkdir chrome
    cd chrome
    mkdir policies
    cd policies
    mkdir managed
    cd managed

    echo "Creating the newpolicy.jsom"
    
}

runjon() {
    clear
    trap 'kill -2 $! >/dev/null 2>&1' INT
    (
        $@
    )
    trap '' INT
    clear
}

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
