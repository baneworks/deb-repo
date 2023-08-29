#!/usr/bin/env bash
# @file bkend
# @brief The switching backend (docker | local).

# fixme: temporary
[[ -n "${SHDPKG_USEDOCKER}" && -n "${SHDPKG_LCRUN}" ]] && (echo "ch0ose local or docker backend, not both"; exit 1)
[[ -n "${SHDPKG_USEDOCKER}" ]] && source $LIBS/docker.sh
[[ -n "${SHDPKG_LCRUN}" ]] && source $LIBS/lcrun.sh