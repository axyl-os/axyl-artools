#!/hint/bash

##{{{ repo

shopt -s extglob

load_valid_names(){
    local conf
    conf="${DATADIR}"/valid-names.conf
    [[ -f "$conf" ]] || return 1
    # shellcheck source=/usr/share/artools/valid-names.conf
    [[ -r "$conf" ]] && . "$conf"
    return 0
}

set_arch_repos(){
    local _testing="$1" _staging="$2" _unstable="$3"
    [[ -z ${valid_names[*]} ]] && load_valid_names
    ARCH_REPOS=("${stable[@]}")
    $_testing && ARCH_REPOS+=("${gremlins[@]}")
    $_staging && ARCH_REPOS+=("${goblins[@]}")
    $_unstable && ARCH_REPOS+=("${wobble[@]}")
}

find_repo(){
    local pkg="$1" pkgarch="${2:-${CARCH}}" repo
    for r in "${ARCH_REPOS[@]}"; do
        [[ -f $pkg/repos/$r-$pkgarch/PKGBUILD ]] && repo=repos/"$r-$pkgarch"
        [[ -f $pkg/repos/$r-any/PKGBUILD ]] && repo=repos/"$r"-any
        [[ -f $pkg/$pkgarch/$r/PKGBUILD ]] && repo="$pkgarch/$r"
    done
    echo "$repo"
}

find_pkg(){
    local searchdir="$1" pkg="$2" result
    result=$(find "$searchdir" -mindepth 2 -maxdepth 2 -type d -name "$pkg")
    echo "$result"
}

tree_loop(){
    local func="$1" pkgs
    for tree in "${ARTIX_TREE[@]}"; do
        pkgs=$(find "${TREE_DIR_ARTIX}/$tree" -name repos -o -name "$CARCH" | sort)
        for _package in ${pkgs}; do
            "$func" "$_package"
        done
    done
}

#}}}
