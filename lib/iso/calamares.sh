#!/hint/bash

#{{{ calamares

write_services_conf(){
    local key1="$1" val1="$2" key2="$3" val2="$4"
    local yaml
    yaml=$(write_yaml_header)
    yaml+=$(write_yaml_map 0 "$key1" "$val1")
    yaml+=$(write_yaml_map 0 "$key2" "$val2")
    yaml+=$(write_yaml_map 0 'services')
    for svc in "${SERVICES[@]}"; do
        yaml+=$(write_yaml_seq 2 "$svc")
    done
    yaml+=$(write_empty_line)
    printf '%s' "${yaml}"
}

write_services_openrc_conf(){
    local conf="$1"/services-openrc.conf
    write_services_conf 'initdDir' '/etc/init.d' 'runlevelsDir' '/etc/runlevels' > "$conf"
}

write_services_runit_conf(){
    local conf="$1"/services-runit.conf
    write_services_conf 'svDir' '/etc/runit/sv' 'runsvDir' '/etc/runit/runsvdir' > "$conf"
}

write_services_s6_conf(){
    local conf="$1"/services-s6.conf
    write_services_conf 'svDir' '/etc/s6/sv' 'dbDir' '/etc/s6/rc/compiled' > "$conf"
}

write_services_suite66_conf(){
    local conf="$1"/services-suite66.conf
    write_services_conf 'svDir' '/etc/66/service' 'runsvDir' '/var/lib/66/system' > "$conf"
}

write_services_dinit_conf(){
    local conf="$1"/services-dinit.conf
    write_services_conf 'initdDir' '/etc/dinit.d' 'runsvDir' '/etc/dinit.d/boot.d' > "$conf"
}

configure_calamares(){
    local mods="$1/etc/calamares/modules"
    if [[ -d "$mods" ]];then
        msg2 "Configuring: Calamares"
        write_services_"${INITSYS}"_conf "$mods"
        sed -e "s|services-openrc|services-${INITSYS}|" \
            -i "$1"/etc/calamares/settings.conf
    fi
}

#}}}
