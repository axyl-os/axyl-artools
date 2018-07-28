#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

get_local_head(){
    echo $(git log --pretty=%H ...refs/heads/$1^ | head -n 1)
}

get_remote_head(){
    echo $(git ls-remote origin -h refs/heads/$1 | cut -f1)
}

is_dirty() {
    [[ $(git diff --shortstat 2> /dev/null | tail -n1) != "" ]] || return 1
    return 0
}

is_untracked(){
    [[ $(git ls-files --others --exclude-standard)  != "" ]] || return 1
    return 0
}

patch_pkg(){
    local pkg="$1" repo="$2"
    case $pkg in
        'glibc')
            sed -e 's|{locale,systemd/system,tmpfiles.d}|{locale,tmpfiles.d}|' \
                -e '/nscd.service/d' \
                -i $pkg/trunk/PKGBUILD
        ;;
        'tp_smapi'|'acpi_call'|'r8168'|'bbswitch'|'broadcom-wl')
            sed -e 's|-ARCH|-ARTIX|g' -i $pkg/trunk/PKGBUILD
        ;;
        'nvidia')
            sed -e 's|-ARCH|-ARTIX|g'  -e 's|for Arch kernel|for Artix kernel|g' \
                -e 's|for LTS Arch kernel|for LTS Artix kernel|g' \
                -i $pkg/trunk/PKGBUILD
        ;;
        'linux')
            sed -e 's|-ARCH|-ARTIX|g' -i $pkg/trunk/PKGBUILD
            sed -e 's|CONFIG_LOCALVERSION=.*|CONFIG_LOCALVERSION="-ARTIX"|' \
                -e 's|CONFIG_DEFAULT_HOSTNAME=.*|CONFIG_DEFAULT_HOSTNAME="artixlinux"|' \
                -e 's|CONFIG_CRYPTO_SPECK=.*|CONFIG_CRYPTO_SPECK=n|' \
                -i $pkg/trunk/config
            cd $pkg/trunk
                updpkgsums
            cd ../..

        ;;
        'licenses')
            sed -e 's|https://www.archlinux.org/|https://www.artixlinux.org/|' -i $pkg/trunk/PKGBUILD
        ;;
        'bash')
            sed -e 's|system.bash_logout)|system.bash_logout artix.bashrc)|' \
            -e "s|etc/bash.|etc/bash/|g" \
            -e 's|"$pkgdir/etc/skel/.bash_logout"|"$pkgdir/etc/skel/.bash_logout"\n  install -Dm644 artix.bashrc $pkgdir/etc/bash/bashrc.d/artix.bashrc|' \
            -i $pkg/trunk/PKGBUILD


            cd $pkg/trunk
                patch -Np 1 -i ${DATADIR}/patches/artix-bash.patch
                updpkgsums
            cd ../..
        ;;
        gstreamer|gst-plugins-*)
            sed -e 's|https://www.archlinux.org/|https://www.artixlinux.org/|' \
                -e 's|(Arch Linux)|(Artix Linux)|' \
                -i $pkg/trunk/PKGBUILD
        ;;
    esac
}

write_jenkinsfile(){
    local pkg="$1" jenkins=Jenkinsfile
    echo '@Library(["PackagePipeline", "BuildPkg", "DeployPkg", "Notify", "PostBuild", "RepoPackage"]) import org.artixlinux.RepoPackage' > $pkg/$jenkins
    echo '' >> $pkg/$jenkins
    echo 'PackagePipeline(new RepoPackage(this))' >> $pkg/$jenkins
    echo '' >> $pkg/$jenkins
}

subrepo_init(){
    local pkg="$1"
    git subrepo init $pkg -r gitea@${git_domain}:packages/$pkg.git -b master
}

subrepo_push(){
    local pkg="$1"
    git subrepo push -u "$pkg" -b master
}

subrepo_pull(){
    local pkg="$1" name="${2:-$1}"
    git subrepo pull "$pkg" -b master -r gitea@${git_domain}:packages/$name.git -u
}

subrepo_clone(){
    local pkg="$1" name="${2:-$1}"
    git subrepo clone gitea@gitea.artixlinux.org:packages/$pkg.git "$name" -b master
}

find_repo_pkgs(){
    local repo="$1"
    local pkgs=$(find $tree -type d -path "*repos/$repo-*")
    echo ${pkgs[*]}
}

find_tree(){
    local tree="$1" pkg="$2"
    local result=$(find $tree -mindepth 2 -maxdepth 2 -type d -name "$pkg")
    result=${result%/*}
    echo ${result##*/}
}

clone_tree(){
    local timer=$(get_timer) host_tree="$1"
    git clone $host_tree.git
    show_elapsed_time "${FUNCNAME}" "${timer}"
}

pull_tree(){
    local branch="master"
    local local_head=$(get_local_head "$branch")
    local remote_head=$(get_remote_head "$branch")
    if [[ "${local_head}" == "${remote_head}" ]]; then
        msg2 "remote changes: no"
    else
        msg2 "remote changes: yes"
        git pull origin "$branch"
    fi
}

push_tree(){
    local branch="master"
    git push origin "$branch"
}

get_import_path(){
    local tree="$1" import_path=
    case $tree in
        packages) import_path=${tree_dir_arch}/packages ;;
        packages-galaxy) import_path=${tree_dir_arch}/community ;;
    esac
    echo $import_path
}

is_valid_repo(){
    local src="$1"
    case $src in
        core|extra|community|multilib|testing|staging|community-testing|community-staging|multilib-testing|multilib-staging|trunk) return 0 ;;
        *) return 1 ;;
    esac
}

find_repo(){
    local pkg="$1" unst="$2" stag="$3" repo=

    if [[ -f $pkg/repos/core-x86_64/PKGBUILD ]];then
        repo=core-x86_64
    elif [[ -f $pkg/repos/core-any/PKGBUILD ]];then
        repo=core-any
    fi

    if [[ -f $pkg/repos/extra-x86_64/PKGBUILD ]];then
        repo=extra-x86_64
    elif [[ -f $pkg/repos/extra-any/PKGBUILD ]];then
        repo=extra-any
    fi

    if [[ -f $pkg/repos/testing-x86_64/PKGBUILD ]];then
        repo=testing-x86_64
    elif [[ -f $pkg/repos/testing-any/PKGBUILD ]];then
        repo=testing-any
    fi

    if $stag;then
        if [[ -f $pkg/repos/staging-x86_64/PKGBUILD ]];then
            repo=staging-x86_64
        elif [[ -f $pkg/repos/staging-any/PKGBUILD ]];then
            repo=staging-any
        fi
    fi

    if [[ -f $pkg/repos/community-x86_64/PKGBUILD ]];then
        repo=community-x86_64
    elif [[ -f $pkg/repos/community-any/PKGBUILD ]];then
        repo=community-any
    fi

    if [[ -f $pkg/repos/community-testing-x86_64/PKGBUILD ]];then
        repo=community-testing-x86_64
    elif [[ -f $pkg/repos/community-testing-any/PKGBUILD ]];then
        repo=community-testing-any
    fi

    if $stag;then
        if [[ -f $pkg/repos/community-staging-x86_64/PKGBUILD ]];then
            repo=community-staging-x86_64
        elif [[ -f $pkg/repos/community-staging-any/PKGBUILD ]];then
            repo=community-staging-any
        fi
    fi

    if [[ -f $pkg/repos/multilib-x86_64/PKGBUILD ]];then
        repo=multilib-x86_64
    fi

    if [[ -f $pkg/repos/multilib-testing-x86_64/PKGBUILD ]];then
        repo=multilib-testing-x86_64
    fi

    if $stag;then
        if [[ -f $pkg/repos/multilib-staging-x86_64/PKGBUILD ]];then
            repo=multilib-staging-x86_64
        fi
    fi

    if $unst;then
        if [[ -f $pkg/repos/gnome-unstable-x86_64/PKGBUILD ]];then
            repo=gnome-unstable-x86_64
        elif [[ -f $pkg/repos/gnome-unstable-any/PKGBUILD ]];then
            repo=gnome-unstable-any
        fi

        if [[ -f $pkg/repos/kde-unstable-x86_64/PKGBUILD ]];then
            repo=kde-unstable-x86_64
        elif [[ -f $pkg/repos/kde-unstable-any/PKGBUILD ]];then
            repo=kde-unstable-any
        fi
    fi
    echo $repo
}

arch_to_artix_repo(){
    local repo="$1"
    case $repo in
        core-*) repo=system ;;
        extra-*) repo=world ;;
        community-x86_64|community-any) repo=galaxy ;;
        multilib-x86_64) repo=lib32 ;;
        testing-*) repo=gremlins ;;
        staging-*) repo=goblins ;;
        multilib-testing-x86_64) repo=lib32-gremlins ;;
        multilib-staging-x86_64) repo=lib32-goblins ;;
        community-testing-*) repo=galaxy-gremlins ;;
        community-staging-*) repo=galaxy-goblins ;;
        kde-unstable-*|gnome-unstable-*) repo=goblins ;;
    esac
    echo $repo
}

# $1: sofile
# $2: soarch
process_sofile() {
    # extract the library name: libfoo.so
    local soname="${1%.so?(+(.+([0-9])))}".so
    # extract the major version: 1
    soversion="${1##*\.so\.}"
    if [[ "$soversion" = "$1" ]] && (($IGNORE_INTERNAL)); then
        continue
    fi
    if ! in_array "${soname}=${soversion}-$2" ${soobjects[@]}; then
    # libfoo.so=1-64
        msg "${soname}=${soversion}-$2"
        soobjects+=("${soname}=${soversion}-$2")
    fi
}

pkgver_equal() {
    if [[ $1 = *-* && $2 = *-* ]]; then
        # if both versions have a pkgrel, then they must be an exact match
        [[ $1 = "$2" ]]
    else
        # otherwise, trim any pkgrel and compare the bare version.
        [[ ${1%%-*} = "${2%%-*}" ]]
    fi
}

find_cached_package() {
    local searchdirs=("$PKGDEST" "$PWD") results=()
    local targetname=$1 targetver=$2 targetarch=$3
    local dir pkg pkgbasename name ver rel arch r results

    for dir in "${searchdirs[@]}"; do
        [[ -d $dir ]] || continue

        for pkg in "$dir"/*.pkg.tar.?z; do
            [[ -f $pkg ]] || continue

            # avoid adding duplicates of the same inode
            for r in "${results[@]}"; do
                [[ $r -ef $pkg ]] && continue 2
            done

            # split apart package filename into parts
            pkgbasename=${pkg##*/}
            pkgbasename=${pkgbasename%.pkg.tar.?z}

            arch=${pkgbasename##*-}
            pkgbasename=${pkgbasename%-"$arch"}

            rel=${pkgbasename##*-}
            pkgbasename=${pkgbasename%-"$rel"}

            ver=${pkgbasename##*-}
            name=${pkgbasename%-"$ver"}

            if [[ $targetname = "$name" && $targetarch = "$arch" ]] &&
                pkgver_equal "$targetver" "$ver-$rel"; then
                results+=("$pkg")
            fi
        done
    done

    case ${#results[*]} in
        0)
            return 1
        ;;
        1)
            printf '%s\n' "${results[0]}"
            return 0
        ;;
        *)
            error 'Multiple packages found:'
            printf '\t%s\n' "${results[@]}" >&2
            return 1
        ;;
    esac
}
