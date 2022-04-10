#!/hint/bash

#{{{ profile

show_profile(){
    msg2 "iso_file: %s" "${iso_file}"
    msg2 "AUTOLOGIN: %s" "${AUTOLOGIN}"
    msg2 "PASSWORD: %s" "${PASSWORD}"
    msg2 "SERVICES: %s" "${SERVICES[*]}"
}

load_profile(){
    local profile_dir="${DATADIR}/iso-profiles"
    [[ -d "${WORKSPACE_DIR}"/iso-profiles ]] && profile_dir="${WORKSPACE_DIR}"/iso-profiles

    root_list="$profile_dir/${profile}/Packages-Root"
    root_overlay="$profile_dir/${profile}/root-overlay"

    [[ -f "$profile_dir/${profile}/Packages-Live" ]] && live_list="$profile_dir/${profile}/Packages-Live"
    [[ -d "$profile_dir/${profile}/live-overlay" ]] && live_overlay="$profile_dir/${profile}/live-overlay"

    common_dir="${DATADIR}/iso-profiles/common"
    [[ -d "$profile_dir"/common ]] && common_dir="${profile_dir}"/common

    [[ -f $profile_dir/${profile}/profile.conf ]] || return 1

    # shellcheck disable=1090
    [[ -r "$profile_dir/${profile}"/profile.conf ]] && . "$profile_dir/${profile}"/profile.conf

    AUTOLOGIN=${AUTOLOGIN:-true}

    PASSWORD=${PASSWORD:-'artix'}

    if [[ -z "${SERVICES[*]}" ]];then
        SERVICES=('acpid' 'bluetoothd' 'cronie' 'cupsd' 'syslog-ng' 'connmand')
    fi

    return 0
}

read_from_list() {
    local list="$1"
    local _space="s| ||g"
    local _clean=':a;N;$!ba;s/\n/ /g'
    local _com_rm="s|#.*||g"

    local _init="s|@initsys@|${INITSYS}|g"

    msg2 "Loading Packages: [%s] ..." "${list##*/}"
    packages+=($(sed "$_com_rm" "$list" \
            | sed "$_space" \
            | sed "$_init" \
            | sed "$_clean"))
}

read_from_services() {
    for svc in "${SERVICES[@]}"; do
        case "$svc" in
            sddm|gdm|lightdm|mdm|greetd|lxdm|xdm)
                packages+=("$svc-${INITSYS}"); display_manager="$svc" ;;
            NetworkManager) packages+=("networkmanager-${INITSYS}") ;;
            connmand) packages+=("connman-${INITSYS}") ;;
            cupsd) packages+=("cups-${INITSYS}") ;;
            bluetoothd) packages+=("bluez-${INITSYS}") ;;
            syslog-ng|metalog) packages+=("$svc-${INITSYS}") ;;
        esac
    done
}

load_pkgs(){
    local pkglist="$1"
    packages=()

    if [[ "${pkglist##*/}" == "Packages-Root" ]]; then
        read_from_list "${common_dir}/Packages-base"
        read_from_list "${common_dir}/Packages-apps"
        read_from_list "${common_dir}/Packages-${INITSYS}"
        [[ -n "${live_list}" ]] && read_from_list "${common_dir}/Packages-xorg"
        read_from_list "$pkglist"
        read_from_services
    else
        read_from_list "$pkglist"
    fi
}

#}}}
