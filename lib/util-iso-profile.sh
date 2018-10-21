#!/bin/bash
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

init_profile(){
    local profdir="$1" prof="$2"

    ROOT_LIST="$profdir/base/Packages-Root"
    ROOT_OVERLAY="$profdir/base/root-overlay"
    LIVE_LIST="$profdir/base/Packages-Live"
    LIVE_OVERLAY="$profdir/base/live-overlay"

    [[ -f "$profdir/$prof/Packages-Root" ]] && ROOT_LIST="$profdir/$prof/Packages-Root"
    [[ -d "$profdir/$prof/root-overlay" ]] && ROOT_OVERLAY="$profdir/$prof/root-overlay"

    [[ -f "$profdir/$prof/Packages-Desktop" ]] && DESKTOP_LIST="$profdir/$prof/Packages-Desktop"
    [[ -d "$profdir/$prof/desktop-overlay" ]] && DESKTOP_OVERLAY="$profdir/$prof/desktop-overlay"

    [[ -f "$profdir/$prof/Packages-Live" ]] && LIVE_LIST="$profdir/$prof/Packages-Live"
    [[ -d "$profdir/$prof/live-overlay" ]] && LIVE_OVERLAY="$profdir/$prof/live-overlay"
}

load_profile(){
    local prof="$1"
    local profdir="${DATADIR}/iso-profiles"
    [[ -d ${WORKSPACE_DIR}/iso-profiles ]] && profdir=${WORKSPACE_DIR}/iso-profiles

    init_profile "$profdir" "$prof"

    [[ -f $profdir/$prof/profile.conf ]] || return 1

    [[ -r $profdir/$prof/profile.conf ]] && source $profdir/$prof/profile.conf

    [[ -z ${DISPLAYMANAGER} ]] && DISPLAYMANAGER="none"

    [[ -z ${AUTOLOGIN} ]] && AUTOLOGIN="true"
    [[ ${DISPLAYMANAGER} == 'none' ]] && AUTOLOGIN="false"

    [[ -z ${HOST_NAME} ]] && HOST_NAME="artix"

    [[ -z ${USER_NAME} ]] && USER_NAME="artix"

    [[ -z ${PASSWORD} ]] && PASSWORD="artix"

    if [[ -z ${ADDGROUPS} ]];then
        ADDGROUPS="video,power,storage,optical,network,lp,scanner,wheel,users,log"
    fi

    if [[ -z ${SERVICES[@]} ]];then
        SERVICES=('acpid' 'bluetooth' 'cronie' 'cupsd' 'syslog-ng' 'NetworkManager')
    fi

    if [[ ${DISPLAYMANAGER} != "none" ]];then
        case "${INITSYS}" in
            'openrc') SERVICES+=('xdm') ;;
            'runit') SERVICES+=("${DISPLAYMANAGER}") ;;
        esac
    fi

    if [[ -z ${SERVICES_LIVE[@]} ]];then
        SERVICES_LIVE=('artix-live' 'pacman-init')
    fi

    return 0
}

write_live_session_conf(){
    local path=$1${SYSCONFDIR}
    [[ ! -d $path ]] && mkdir -p "$path"
    local conf=$path/live.conf
    msg2 "Writing %s" "${conf##*/}"
    echo '# live session configuration' > ${conf}
    echo '' >> ${conf}
    echo '# autologin' >> ${conf}
    echo "AUTOLOGIN=${AUTOLOGIN}" >> ${conf}
    echo '' >> ${conf}
    echo '# live user name' >> ${conf}
    echo "USERNAME=${USERNAME}" >> ${conf}
    echo '' >> ${conf}
    echo '# live password' >> ${conf}
    echo "PASSWORD=${PASSWORD}" >> ${conf}
    echo '' >> ${conf}
    echo '# live group membership' >> ${conf}
    echo "ADDGROUPS='${ADDGROUPS}'" >> ${conf}
}

load_pkgs(){
    local pkglist="$1" init="$2"
    info "Loading Packages: [%s] ..." "${pkglist##*/}"

    local _init="s|@$init||g"
    case "$init" in
        'openrc') _init_rm1="s|@runit.*||g"; _init_rm2="s|@s6*||g" ;;
        's6') _init_rm1="s|@runit.*||g"; _init_rm2="s|@openrc.*||g" ;;
        'runit') _init_rm1="s|@s6.*||g"; _init_rm2="s|@openrc.*||g" ;;
    esac

    local _space="s| ||g" \
        _clean=':a;N;$!ba;s/\n/ /g' \
        _com_rm="s|#.*||g"

    packages=($(sed "$_com_rm" "$pkglist" \
            | sed "$_space" \
            | sed "$_purge" \
            | sed "$_init" \
            | sed "$_init_rm1" \
            | sed "$_init_rm2" \
            | sed "$_clean"))
}
