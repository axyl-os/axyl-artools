#!/hint/bash

#{{{ services

add_svc_openrc(){
    local mnt="$1" names="$2" rlvl="${3:-default}"
    for svc in $names; do
        if [[ -f $mnt/etc/init.d/$svc ]];then
            msg2 "Setting %s: [%s]" "${INITSYS}" "$svc"
            chroot "$mnt" rc-update add "$svc" "$rlvl" &>/dev/null
        fi
    done
}

add_svc_runit(){
    local mnt="$1" names="$2" rlvl="${3:-default}"
    for svc in $names; do
        if [[ -d $mnt/etc/runit/sv/$svc ]]; then
            msg2 "Setting %s: [%s]" "${INITSYS}" "$svc"
            chroot "$mnt" ln -s /etc/runit/sv/"$svc" /etc/runit/runsvdir/"$rlvl" &>/dev/null
        fi
    done
}

add_svc_s6(){
    local mnt="$1" names="$2" rlvl="${3:-default}" dep
    dep="$mnt"/etc/s6/sv/"$display_manager"-srv/dependencies.d
    for svc in $names; do
        msg2 "Setting %s: [%s]" "${INITSYS}" "$svc"
        chroot "$mnt" s6-service add "$rlvl" "$svc"
        if [[ "$svc" == "$display_manager" ]]; then
            if [[ -d "$dep" ]]; then
                touch "$dep"/artix-live
            fi
        fi
    done

    chroot "$mnt" s6-db-reload -r

    local src=/etc/s6/current skel=/etc/s6/skel getty='/usr/bin/agetty -L -8 tty7 115200'
    # rebuild s6-linux-init binaries
    chroot "$mnt" rm -r "$src"
    chroot "$mnt" s6-linux-init-maker -1 -N -f "$skel" -G "$getty" -c "$src" "$src"
    chroot "$mnt" mv "$src"/bin/init "$src"/bin/s6-init
    chroot "$mnt" cp -a "$src"/bin /usr
}

add_svc_suite66(){
    local mnt="$1" names="$2"
    for svc in $names; do
        if [[ -f "$mnt"/etc/66/service/"$svc" ]]; then
            msg2 "Setting %s: [%s]" "${INITSYS}" "$svc"
            chroot "$mnt" 66-enable -t default "$svc" &>/dev/null
        fi
    done
}

add_svc_dinit(){
    local mnt="$1" names="$2"
    for svc in $names; do
        if [[ -d $mnt/etc/dinit.d/boot.d ]]; then
            msg2 "Setting %s: [%s]" "${INITSYS}" "$svc"
            chroot "$mnt" ln -s ../"$svc" /etc/dinit.d/boot.d/"$svc" &>/dev/null
        fi
    done
}

#}}}
