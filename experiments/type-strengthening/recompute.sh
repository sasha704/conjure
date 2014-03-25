#!/bin/bash

function list_all_essence() {
    find * -name "*.essence"
}
export -f list_all_essence

function do_ts1() {
    ESSENCE="$1"
    conjure --mode typeStrengthening --in "${ESSENCE}" > "${ESSENCE}.typeStrengthening"
    conjure --mode diff "${ESSENCE}.typeStrengthening" "${ESSENCE}.expected" 2> /dev/null
    if [ $? -eq 0 ] ; then
        echo "pass ${ESSENCE}"
    else
        echo "fail ${ESSENCE}"
    fi
}
export -f do_ts1

function do_ts() {
    parallel --no-notice -k do_ts1 ::: $(list_all_essence)
}
export -f do_ts

function rm_output_files() {
    find . -name "*.typeStrengthening" -delete
}
export -f do_ts

function recompute() {
    do_ts
    rm_output_files
}
export -f recompute
