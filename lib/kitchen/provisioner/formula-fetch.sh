#!/bin/bash

# Usage:
#    ./formula-fetch.sh <Formula URL> <Name> <Branch>
#
# Example:
#    GIT_FORMULAS_PATH=.vendor/formulas ./formula-fetch.sh https://github.com/salt-formulas/salt-formula-salt
#    --
#    GIT_FORMULAS_PATH=/usr/share/salt-formulas/env/_formulas
#    xargs -n1 ./formula-fetch.sh < dependencies.txt


# Parse git dependencies from metadata.yml
# $1 - path to <formula>/metadata.yml
# sample to output:
#    https://github.com/salt-formulas/salt-formula-git git
#    https://github.com/salt-formulas/salt-formula-salt salt
function fetchDependencies() {
    METADATA="$1";
    grep -E "^dependencies:" "$METADATA" >/dev/null || return 0
    # shellcheck disable=SC2086
    (python - "$METADATA" | while read -r dep; do fetchGitFormula $dep; done) <<-DEPS 
		import sys,yaml
		for dep in yaml.load(open(sys.argv[1], "ro"))["dependencies"]:
		  print("{source} {name}").format(**dep)
		DEPS
}

# Fetch formula from git repo
# $1 - formula git repo url
# $2 - formula name (optional)
# $3 - branch (optional)
function fetchGitFormula() {
    test -n "${FETCHED}" || declare -a FETCHED=()
    export GIT_FORMULAS_PATH=${GIT_FORMULAS_PATH:-/usr/share/salt-formulas/env/_formulas}
    mkdir -p "$GIT_FORMULAS_PATH"
    if [ -n "$1" ]; then
        source="$1"
        name="$2"
        test -n "$name" || name="${source//*salt-formula-}"
        test -z "$3" && branch=master || branch=$3
        if ! [[ "${FETCHED[*]}" =~ $name ]]; then # dependency not yet fetched
          echo "Fetching: $name"
          if test -e "$GIT_FORMULAS_PATH/$name"; then
              pushd "$GIT_FORMULAS_PATH/$name" &>/dev/null
              test ! -e .git || git pull -r
              popd &>/dev/null
          else
              echo "git clone $source $GIT_FORMULAS_PATH/$name -b $branch"
              git clone "$source" "$GIT_FORMULAS_PATH/$name" -b "$branch"
          fi
          # install dependencies
          FETCHED+=($name)
          if [ -e "$GIT_FORMULAS_PATH/$name/metadata.yml" ]; then
            fetchDependencies "$GIT_FORMULAS_PATH/$name/metadata.yml"
          fi
        fi
    else
        echo Usage: fetchGitFormula "<git repo>" "[local formula directory name]" "[branch]"
    fi
}

function linkFormulas() {
  # OPTIONAL: Link formulas from git/pkg

  SALT_ROOT=$1
  SALT_ENV=${2:-/usr/share/salt-formulas/env}

  if [[ -e "$SALT_ENV" ]]; then
    # form git, development versions
    if [[ -e "$SALT_ENV/_formulas" ]]; then
      GIT_FORMULA_LIST=$(find "$SALT_ENV"/_formulas -maxdepth 1 -mindepth 1 -type d)
      for formula in $GIT_FORMULA_LIST
      do
        name=$(basename "$formula")
        ln -fs "$formula/$name" "$SALT_ROOT/$name"
        find "$formula" -maxdepth 1 -mindepth 1 -type d |grep -E "_(modules|states|grains|renderers|returners)" | xargs -I{} \
          basename {}| xargs -I{} cp -rs "$formula"/{} "$SALT_ROOT"/
      done
    fi

    # form pkgs
    find "$SALT_ENV" -maxdepth 1 -mindepth 1 -path "*_formulas*" -prune -o -name "*" -type d -print0| xargs -I{} -0 -n1 --no-run-if-empty basename {} | xargs -I{} --no-run-if-empty \
      ln -fs "$SALT_ENV"/{} "$SALT_ROOT"/{};
  fi

}

# detect if file is being sourced
[[ "$0" != "${BASH_SOURCE[0]}" ]] || {
    # if executed, run implicit function
    fetchGitFormula "${@}"
}

