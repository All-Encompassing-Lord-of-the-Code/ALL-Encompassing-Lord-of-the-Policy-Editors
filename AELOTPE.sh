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



install() {
    local url="$1"
    local dest="$2"
    local mode="${3:-0755}"
    local file="$DEPS_TMP/$(basename "$dest")"

    if [ -e "$dest" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$dest")" || return 1

    echo "[DEPS] Installing $(basename "$dest")..."

    if ! curl -fsSL --retry 3 "$url" -o "$file" ||
        [ ! -s "$file" ]; then
        echo "[ERROR] Download failed: $dest"
        return 1
    fi

    if ! command install -m "$mode" "$file" "$dest" ||
        [ ! -s "$dest" ]; then
        echo "[ERROR] Installation failed: $dest"
        return 1
    fi
}

link() {
    local target="$1"
    local dest="$2"

    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$target" ]; then
        return 0
    fi

    ln -sfn "$target" "$dest" || return 1

    [ -L "$dest" ] && [ "$(readlink "$dest")" = "$target" ] || {
        echo "[ERROR] Link failed: $dest"
        return 1
    }
}

install_deps() {
    local arch

    DEPS_DIR="/mnt/stateful_partition"
    DEPS_TMP="$(mktemp -d)" || return 1

    case "$(uname -m)" in
        x86_64|amd64)
            arch="x86_64"
            ;;
        aarch64|arm64)
            arch="aarch64"
            ;;
        *)
            echo "[ERROR] Unsupported architecture."
            rm -rf "$DEPS_TMP"
            return 1
            ;;
    esac

    mkdir -p "$DEPS_DIR" || {
        rm -rf "$DEPS_TMP"
        return 1
    }

    case "$arch" in
        x86_64)
            py_url="$PY_BASE/cpython-3.16.0a1+20261026-x86_64-unknown-linux-musl-install_only_stripped.tar.gz"
            binary="chattr-x86_64"
            ;;
        aarch64)
            py_url="$PY_BASE/cpython-3.16.0a1+20261026-aarch64-unknown-linux-musl-install_only_stripped.tar.gz"
            binary="chattr-arm64"
            ;;
    esac

    if [ ! -x "$DEPS_DIR/python3/bin/python3" ]; then
        echo "[DEPS] Installing CPython..."

        if ! curl -fsSL --retry 3 "$py_url" -o "$DEPS_TMP/python.tar.gz" ||
            ! tar -I zstd -xf "$DEPS_TMP/python.tar.gz" \
                -C "$DEPS_DIR" --strip-components=1 ||
            [ ! -x "$DEPS_DIR/python3/bin/python3" ]; then
            echo "[ERROR] CPython installation failed."
            rm -rf "$DEPS_TMP"
            return 1
        fi
    fi

    link "$DEPS_DIR/python3/bin/python3" /usr/bin/python3 || {
        rm -rf "$DEPS_TMP"
        return 1
    }

    link "$DEPS_DIR/python3/bin/python3" /usr/bin/python || {
        rm -rf "$DEPS_TMP"
        return 1
    }

    install \
        "https://github.com/All-Encompassing-Lord-of-the-Policy-Editors/ALL-Encompassing-Lord-of-the-Policy-Editors/raw/main/bin/$binary" \
        "$DEPS_DIR/chattr" || {
        rm -rf "$DEPS_TMP"
        return 1
    }

    link "$DEPS_DIR/chattr" /usr/bin/chattr || {
        rm -rf "$DEPS_TMP"
        return 1
    }

    rm -rf "$DEPS_TMP"

    echo "[DEPS] Dependencies ready."
}

install_deps
ensure_rw
main_menu
