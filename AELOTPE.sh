#!/bin/bash

PY_BASE="https://github.com/astral-sh/python-build-standalone/releases/download/20261026"

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

if [ $(id -u) -ne 0 ]; then
    echo "Run this script as root (sudo su)"
    exit
fi

echo "  
      WELCOME TO THE ALL ENCOMPASSING LORD OF THE POLICY EDITORS!
      A policy tool for all chrome os versions."

main_menu() {
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
    echo "You chose pollen policy editor, this is for r131 and below."
    cd /
    mkdir /etc/opt
    mkdir /etc/opt/chrome
    mkdir /etc/opt/chrome/policies
    mkdir /etc/opt/chrome/policies/managed
    curl -fsSL https://raw.githubusercontent.com/All-Encompassing-Lord-of-the-Code/ALL-Encompassing-Lord-of-the-Policy-Editors/main/policy.json -o /etc/opt/chrome/policies/managed/policy.json

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
        echo "ERROR: make_dev_ssd.sh not found or not executable."
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
        echo "ERROR: No supported storage devices found."
        return 1
    fi

    if (( failed )); then
        echo "ERROR: Rootfs verification changes were unsuccessful."
        return 1
    fi

    echo "Rootfs verification changes completed."
    echo "Reboot and rerun to apply changes."

    exit 0
}

install_python() {
    if command -v python3 >/dev/null; then
        log "Python already installed."
        return
    fi
    arch="$(uname -m)"
    case "$arch" in
        amd64|x86_64) PY_URL="$PY_BASE/cpython-3.16.0a1+20261026-x86_64-unknown-linux-musl-install_only_stripped.tar.gz" ;;
        aarch64|arm64) PY_URL="$PY_BASE/cpython-3.16.0a1+20261026-aarch64-unknown-linux-musl-install_only_stripped.tar.gz" ;;
        *) error "Unsupported architecture: $arch" ;;
    esac
    tmp="/tmp/python"
    rm -rf "$tmp"
    mkdir -p "$tmp"
    curl -fsSL "$PY_URL" -o "$tmp/python.tar.gz" || error "Python download failed"
    rm -rf /mnt/stateful_partition/python3
    mkdir -p /mnt/stateful_partition/python3
    tar -I zstd -xf "$tmp/python.tar.gz" -C /mnt/stateful_partition/python3 --strip-components=1 || error "Python extract failed"
    ln -sf /mnt/stateful_partition/python3/bin/python3 /usr/bin/python3
    ln -sf /mnt/stateful_partition/python3/bin/python3 /usr/bin/python
    rm -rf "$tmp"
    log "Python installed."
}

ensure_rw
main_menu
