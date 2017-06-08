#!/bin/bash

function apt_repo_add {
  id="$1"
  arch="$2"
  rurl="$3"
  comp="$4"
  dist="$5"
  rkey="$6"
  test -e /tmp/apt_repo_vendor_"${id}".key || {
    echo "-----> Configuring formula apt vendor_repo ${rurl}"
    eval "$(cat /etc/lsb-release)"
    if curl -k "${rkey}" -o /tmp/apt_repo_vendor_"${id}".key; then
      echo "deb ${arch} ${rurl} ${dist} ${comp}" | tee /etc/apt/sources.list.d/vendor-repo.list
      apt-key add /tmp/apt_repo_vendor_"${id}".key
    fi
  };
}

# detect if file is being sourced
[[ "$0" != "${BASH_SOURCE[@]}" ]] || {
    # if executed, run implicit function
    #apt_repo_add "${@}"
    echo 'Usage: apt_repo_add "custom id" "arch" "repo url" "components" "distribution" "repo gpg key"';
}

