#!/bin/bash
# stop on any fail
set -e

function stopWithMsg() {
    printf "Error:" 1>&2
    printf "%s\n" "$@" 1>&2
    exit 1
}

[[ "$#" -ge "1" ]] || stopWithMsg "$0 requires path as argument."
[[ -d "$1" ]] || stopWithMsg "$1 is not directory!"

# format: YYWW.CDX.BBBBB
# where:
# YYWW.C = current commit user friendly identifier
# YY - 23 (year)
# WW - 09 (num week since begin of year 01-52)
# C - 3 (num commits since begin of week in current branch 1-99'999)

# D - build configuration id (1-9)
# X - (num uncommited files 0-9) - limited with 9
# BBBBB =
#   $BUILD_NUMBER if CI/CD is used
#   git hash converted to decimal (1-65'535)

BUILD_NUMBER="$2"
BUILD_CFG_ID="${3:-0}"

gitCommitDate="$(git log -1 --format=%ci "$1" 2>/dev/null || true)"
if [[ -z "$gitCommitDate" ]]; then
    # if folder you want to check does not have any files in git - use 0.0X.0
    numUncommitedFiles=$(find "$1" -type f | wc -l)
    numUncommitedFiles=$(( $numUncommitedFiles < 9 ? $numUncommitedFiles : 9 ))
    echo "0.0${BUILD_CFG_ID}${numUncommitedFiles}.0"
    exit 0
fi

YYWW="$(TZ=UTC-00 date -j -f "%Y-%m-%d %T %z" "${gitCommitDate}" "+%y%W")"

weekStartTime="$(date -j -f "%y%W %T %z" "${YYWW} 00:00:00 +0000" "+%Y-%m-%dT%T%z")"

numCommitsSinceStartWeek="$(git log --since="${weekStartTime}" --format="%h" "$1" | wc -l)"
numCommitsSinceStartWeek=$((numCommitsSinceStartWeek)) # trim spaces

# no quotes - to truncate spaces
numUncommitedFiles=$(git status -s "$1" | wc -l)
numUncommitedFiles=$(( $numUncommitedFiles < 9 ? $numUncommitedFiles : 9 ))

GIT_SHA="$(printf '0%d\n' 0x"$(git log -1 --format="%h" --abbrev=4 "$1" | cut -c1-4)")"

echo "${YYWW}.${numCommitsSinceStartWeek}${BUILD_CFG_ID}${numUncommitedFiles}.${BUILD_NUMBER:-${GIT_SHA}}"
