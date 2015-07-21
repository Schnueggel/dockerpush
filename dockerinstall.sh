#!/usr/bin/env bash
set -e

GITURL=$1

git ls-remote "$GITURL"  &>-
if [ "$?" -ne 0 ]; then
    echo "[ERROR] Unable to read from '$GITURL'"
    exit 1;
fi

REPO=$(basename $GITURL .git)

if [ ! -d $REPO ];
then
    git clone $GITURL
else
    cd ./$REPO
    git push
fi

