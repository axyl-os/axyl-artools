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
    local mnt="$1" names="$2" rlvl="${3:-default}" error ret
    local db=/etc/s6/rc/compiled
    for svc in $names; do
        error=false
        chroot "$mnt" s6-rc-db -c "$db" type "$svc" &> /dev/null || error=true
        ret="$?"
        if [ $ret -eq 0 ] && [[ "$error" == false ]]; then
            msg2 "Setting %s: [%s]" "${INITSYS}" "$svc"
            chroot "$mnt" s6-rc-bundle-update -c "$db" add "$rlvl" "$svc"
        fi
    done

    local rlvl=/etc/s6/current
    # rebuild s6-linux-init binaries
    chroot "$mnt" rm -r "$rlvl"
    chroot "$mnt" s6-linux-init-maker -1 -N -f /etc/s6/skel -G "/usr/bin/agetty -L -8 tty7 115200" -c "$rlvl" "$rlvl"
    chroot "$mnt" mv "$rlvl"/bin/init "$rlvl"/bin/s6-init
    chroot "$mnt" cp -a "$rlvl"/bin /usr
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
