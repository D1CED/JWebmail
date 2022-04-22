#!/usr/bin/env sh

set -euC

test () {
    eval "prove -l ${1-} t/"
}

start () {
    script/jwebmail daemon
}

logrotate () {
    mode=${1:-development}
    mv -i "log/$mode.log" "log/${mode}_$(date --iso-8601=minutes).log"
}

linelength () {
    files=${1:-'README.md CHANGES LICENSE'}
    for file in $files
    do
        fold -s -w 85 "$file" | diff "$file" -
    done
}

follow () {
    mode=${1:-development}
    tail -f "log/$mode.log"
}

check_manifest () {
    perl -nE 'chomp; say unless -e' MANIFEST
}

cmd=$1
shift
if [ "$(command -v "$cmd")" = "$cmd" ]
then eval "$cmd" "$@"
else echo "unkown commad '$cmd'"; exit 1
fi
