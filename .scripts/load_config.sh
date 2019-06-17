#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

load_config() {
    if [[ ! -d "${STORE_PATH}" ]]; then
        mkdir -p "${STORE_PATH}"
    fi

    for CONFIG_FILE_OLD in ${CONFIG_FILES_OLD[@]}; do
        if [[ -f "${CONFIG_FILE_OLD}" ]]; then
            mv "${CONFIG_FILE_OLD}" "${CONFIG_FILE}"
        fi
    done

    if [[ ! -f "${CONFIG_FILE}" ]]; then
        touch ${CONFIG_FILE}
    fi
    shopt -s extglob
    tr -d '\r' < $CONFIG_FILE > $CONFIG_FILE.unix

    while IFS='= ' read -r lhs rhs
    do
        if [[ ! $lhs =~ ^\ *# && -n $lhs ]]; then
            rhs="${rhs%%\#*}"    # Del in line right comments
            rhs="${rhs%%*( )}"   # Del trailing spaces
            rhs="${rhs%\"*}"     # Del opening string quotes
            rhs="${rhs#\"*}"     # Del closing string quotes
            config[$lhs]="$rhs"
            log "config[$lhs]=\"$rhs\""
        fi
    done < $CONFIG_FILE.unix

    rm $CONFIG_FILE.unix
}
