#!/bin/bash
#
# Copyright (C) 2018-19 artoo@artixlinux.org
# Copyright (C) 2018 Artix Linux Developers
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
    echo $(git log --pretty=%H ...refs/heads/master^ | head -n 1)
}

get_remote_head(){
    echo $(git ls-remote origin -h refs/heads/master | cut -f1)
}

get_pkg_org(){
    local pkg="$1" org= sub=
    case ${pkg} in
        ruby-*) org=${pkg:0:6}; sub="${org:5}"; echo "packagesRuby" ;;
        perl-*) org=${pkg:0:6}; sub="${org:5}"; echo "packagesPerl" ;;
        python-*) org=${pkg:0:8}; sub="${org:7}"; echo "packagesPython" ;;
        python2-*) org=${pkg:0:9}; sub="${org:8}"; echo "packagesPython" ;;
        lib32*) org=${pkg:0:7}; sub="${org:6}"; echo "packagesL" ;; #"packages${sub^^}" ;;
#         lib*) org=${pkg:0:4}; sub="${org:3}"; echo "packagesLib${sub^^}" ;;
        *) org=${pkg:0:1}; echo "packages${org^^}" ;;
    esac
}

subrepo_push(){
    local pkg="$1"
    msg2 "Push (%s)" "$pkg"
    git subrepo push "$pkg"
}

subrepo_clean(){
    local pkg="$1"
    msg2 "Clean (%s)" "$pkg"
    git subrepo clean "$pkg"
}

subrepo_pull(){
    local pkg="$1"
    msg2 "Pull (%s)" "$pkg"
    git subrepo pull "$pkg"
}

subrepo_clone(){
    local pkg="$1" org="$2"
    local gitname=$(get_compliant_name "$pkg")
    msg2 "Clone [%s] from (%s)" "$pkg" "$org/$gitname"
    git subrepo clone gitea@"${GIT_DOMAIN}":"$org"/"$gitname".git "$pkg"
}

clone_tree(){
    local timer=$(get_timer) url="$1" tree="$2" os="${3:-$(get_osname)}"

    msg "Cloning (%s) ..." "$tree" "$os"

    git clone $url/$tree.git
    show_elapsed_time "${FUNCNAME}" "${timer}"
}

has_changes(){
    local head_l="$1" head_r="$2"
    if [[ "$head_l" == "$head_r" ]]; then
        msg2 "remote changes: no"
        return 1
    else
        msg2 "remote changes: yes"
        return 0
    fi
}

pull_tree(){
    local tree="$1" local_head="$2" os="${3:-$(get_osname)}"
    local remote_head=$(get_remote_head)

    msg "Checking %s (%s)" "${tree}" "$os"
    if $(has_changes "${local_head}" "${remote_head}");then
        git pull origin master
    fi
}

push_tree(){
    local tree="$1"
    msg "Update (%s)" "${tree}"
    git push origin master
}

write_jenkinsfile(){
    local pkg="$1"
    local jenkins=$pkg/Jenkinsfile

    echo "@Library('artix-ci') import org.artixlinux.RepoPackage" > $jenkins
    echo '' >> $jenkins
    echo 'PackagePipeline(new RepoPackage(this))' >> $jenkins
    echo '' >> $jenkins

    git add $jenkins
}

write_agentyaml(){
    local pkg="$1"
    local agent=$pkg/.artixlinux/agent.yaml label='master'
    [[ -d $pkg/.artixlinux ]] || mkdir $pkg/.artixlinux

    echo '%YAML 1.2' > $agent
    echo '---' >> $agent
    echo '' >> $agent
    echo "label: $label" >> $agent
    echo '' >> $agent

    git add $agent
}

commit_jenkins_files(){
    local pkg="$1"

    write_jenkinsfile "$pkg"
    write_agentyaml "$pkg"

    git commit -m "add jenkinsfile & .artixlinux/agent.yaml"
}

config_tree(){
    local tree="$1"
    cd $tree
        git config --bool pull.rebase true
        git config commit.gpgsign true
        if [[ -n "${GPGKEY}" ]];then
            git config user.signingkey "${GPGKEY}"
        else
            warning "No GPGKEY configured in makepkg.conf!"
        fi
    cd ..
}

subrepo_new(){
    local pkg="$1" tree="$2" team="${3:-$2}"
    local dest=${TREE_DIR_ARTIX}/$tree/$pkg/trunk

    cd ${TREE_DIR_ARTIX}/$tree

    local org=$(get_pkg_org "$pkg")

    create_repo "$pkg" "$org"

    add_repo_to_team "$pkg" "$org" "$team"

    subrepo_clone "$pkg" "$org"

    prepare_dir "$dest"

    commit_jenkins_files "$pkg"
}