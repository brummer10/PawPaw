#!/bin/bash

set -e

cd $(dirname ${0})
PAWPAW_ROOT="${PWD}"

# ---------------------------------------------------------------------------------------------------------------------

target="${1}"

if [ -z "${target}" ]; then
    echo "usage: ${0} <target> <plugin1> ..."
    exit 1
fi

shift

# ---------------------------------------------------------------------------------------------------------------------

source setup/check_target.sh
source setup/env.sh

# ---------------------------------------------------------------------------------------------------------------------

function download_and_install_innosetup {
    local dlfile="${PAWPAW_DOWNLOADDIR}/innosetup-6.0.5.exe"
    local pkgdir="${PAWPAW_BUILDDIR}/innosetup-6.0.5"

    if [ ! -f "${dlfile}" ]; then
        # FIXME proper dl version
        curl -L https://jrsoftware.org/download.php/is.exe?site=2 -o "${dlfile}"
    fi

    if [ ! -d "${pkgdir}"/drive_c ]; then
        env WINEARCH="${PAWPAW_TARGET}" WINEDLLOVERRIDES="mscoree,mshtml=" WINEPREFIX="${pkgdir}" wineboot -u
    fi

    if [ ! -f "${pkgdir}"/drive_c/InnoSeup/ISCC.exe ]; then
        env WINEARCH="${PAWPAW_TARGET}" WINEPREFIX="${pkgdir}" wine "${dlfile}" /allusers /dir=C:\\InnoSeup /nocancel /norestart /verysilent
    fi
}

function create_innosetup_exe {
    local pkgdir="${PAWPAW_BUILDDIR}/innosetup-6.0.5"
    local iscc="${pkgdir}/drive_c/InnoSeup/ISCC.exe"

    echo "#define VERSION \"$(cat VERSION)\"" > /tmp/pawpaw/version.iss
    env WINEARCH="${PAWPAW_TARGET}" WINEPREFIX="${pkgdir}" wine "${iscc}" "setup/inno/${PAWPAW_TARGET}.iss"
}

# ---------------------------------------------------------------------------------------------------------------------

if [ "${WIN32}" -eq 1 ]; then
    download_and_install_innosetup
    rm -rf /tmp/pawpaw
    mkdir /tmp/pawpaw
    touch /tmp/pawpaw/components.iss
    touch /tmp/pawpaw/lv2bundles.iss
    PAWPAW_WINE_LV2DIR="Z:$(echo ${PAWPAW_PREFIX} | tr -t '/' '\\')\\lib\\lv2\\"
fi

# ---------------------------------------------------------------------------------------------------------------------

for plugin in ${@}; do
    pfile="${PAWPAW_ROOT}/plugins/${plugin}.json"

    if [ ! -e "${pfile}" ]; then
        echo "Requested plugin file '${pfile}' does not exist"
        exit 2
    fi

    name=$(jq -crM .name ${pfile})
    sname=$(echo ${name} | tr -t '-' '_')
    lv2bundles=($(jq -crM .lv2bundles[] ${pfile}))

    if [ "${WIN32}" -eq 1 ]; then
        echo "Name: ${sname}; Description: \"${name}\"; Types: full;" >> /tmp/pawpaw/components.iss
    fi

    for lv2bundle in ${lv2bundles[@]}; do
        if [ "${WIN32}" -eq 1 ]; then
            echo "Source: \"${PAWPAW_WINE_LV2DIR}${lv2bundle}\\*\"; DestDir: \"{commoncf}\\LV2\\${lv2bundle}\"; Components: ${sname}; Flags: recursesubdirs" >> /tmp/pawpaw/lv2bundles.iss
        fi
    done
done

if [ "${WIN32}" -eq 1 ]; then
    create_innosetup_exe
    rm -rf /tmp/pawpaw
fi

# ---------------------------------------------------------------------------------------------------------------------
