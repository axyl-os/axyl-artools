#!/hint/bash

#{{{ initcpio

make_checksum(){
    local file="$1"
    msg2 "Creating md5sum ..."
    cd "${iso_root}${live_dir}"
    md5sum "$file" > "$file".md5
    cd "${OLDPWD}"
}

make_sig () {
    local file="$1"
    msg2 "Creating signature file..."
    chown "${owner}:$(id --group "${owner}")" "${iso_root}${live_dir}"
    su "${owner}" -c "gpg --detach-sign --output $file.sig --default-key ${GPG_KEY} $file"
    chown "root:root" "${iso_root}${live_dir}"
}

export_gpg_publickey() {
    key_export=${WORKSPACE_DIR}/pubkey.gpg
    if [[ ! -e "${key_export}" ]]; then
        gpg --batch --output "${key_export}" --export "${GPG_KEY}"
    fi
}

prepare_initramfs_mkinitcpio() {
    local mnt="$1" packages=() mkinitcpio_conf k

    mkinitcpio_conf=mkinitcpio-default.conf
    [[ "${profile}" == 'base' ]] && mkinitcpio_conf=mkinitcpio-pxe.conf
    k=$(<"$mnt"/usr/src/linux/version)

    read_from_list "${common_dir}/Packages-boot"
    basestrap "${basestrap_args[@]}" "$mnt" "${packages[@]}"

    if [[ -n "${GPG_KEY}" ]]; then
        exec {ARTIX_GNUPG_FD}<>"${key_export}"
        export ARTIX_GNUPG_FD
    fi

    artix-chroot "$mnt" mkinitcpio -k "$k" \
        -c /etc/"$mkinitcpio_conf" \
        -g /boot/initramfs.img

    if [[ -n "${GPG_KEY}" ]]; then
        exec {ARTIX_GNUPG_FD}<&-
        unset ARTIX_GNUPG_FD
    fi
    if [[ -f "${key_export}" ]]; then
        rm "${key_export}"
    fi
    cp "$mnt"/boot/initramfs.img "${iso_root}"/boot/initramfs-"${arch}".img
    prepare_boot_extras "$mnt"
}

configure_grub_mkinitcpio() {
    msg "Configuring grub kernel options ..."
    local ro_opts=()
    local rw_opts=()
    local kopts=("label=${iso_label}")

    [[ "${profile}" != 'base' ]] && kopts+=('overlay=livefs')

    sed -e "s|@kopts@|${kopts[*]}|" \
        -e "s|@ro_opts@|${ro_opts[*]}|" \
        -e "s|@rw_opts@|${rw_opts[*]}|" \
        -i "${iso_root}"/boot/grub/kernels.cfg
}

#}}}
