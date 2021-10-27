#!/hint/bash

#{{{ pkg conf

load_pkg_config(){

    local conf="$1/artools-pkg.conf"

    [[ -f "$conf" ]] || return 1

    # shellcheck source=/etc/artools/artools-pkg.conf
    [[ -r "$conf" ]] && . "$conf"

    local git_domain="gitea.artixlinux.org"

    GIT_URL=${GIT_URL:-"https://${git_domain}"}

    GIT_SSH=${GIT_SSH:-"gitea@${git_domain}"}

    GIT_TOKEN=${GIT_TOKEN:-''}

    TREE_DIR_ARTIX=${TREE_DIR_ARTIX:-"${WORKSPACE_DIR}/artixlinux"}

    ARTIX_TREE=(
        packages community
        packages-{gfx,gtk,media,net,qt5,xorg}
    )

    local dev_tree=(
        packages-{llvm,python,perl,java,ruby}
        python-{world,galaxy}
    )

    local init_tree=(packages-{openrc,runit,s6,suite66,dinit})

    local desktop_tree=(
        packages-{kf5,plasma,kde,qt6}
        packages-{lxqt,gnome,cinnamon,mate,xfce,wm}
    )

    [[ -z ${TREE_NAMES_ARTIX[*]} ]] && \
    TREE_NAMES_ARTIX=(
        packages-kernel
        "${init_tree[@]}"
        "${dev_tree[@]}"
        "${desktop_tree[@]}"
        packages-devel
        packages-lib32
    )

    ARTIX_TREE+=("${TREE_NAMES_ARTIX[@]}")

    TREE_DIR_ARCH=${TREE_DIR_ARCH:-"${WORKSPACE_DIR}/archlinux"}

    [[ -z ${ARCH_TREE[*]} ]] && \
    ARCH_TREE=(svntogit-{packages,community})

    REPOS_ROOT=${REPOS_ROOT:-"${WORKSPACE_DIR}/repos"}

    REPOS_MIRROR=${REPOS_MIRROR:-'http://mirror1.artixlinux.org/repos'}

    HOST_TREE_ARCH=${HOST_TREE_ARCH:-'https://github.com/archlinux'}

    DBEXT=${DBEXT:-'gz'}

    return 0
}

#}}}

load_pkg_config "${USER_CONF_DIR}" || load_pkg_config "${SYSCONFDIR}"

prepare_dir "${REPOS_ROOT}"
prepare_dir "${TREE_DIR_ARTIX}"
prepare_dir "${TREE_DIR_ARCH}"
