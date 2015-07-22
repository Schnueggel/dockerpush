#!/usr/bin/env bash
set -e

GITURL=$1

git ls-remote "$GITURL"  &>-
if [ "$?" -ne 0 ]; then
    echo "[ERROR] Unable to read from '$GITURL'"
    exit 1;
fi

if [ $# -eq 2 ];
then
    GITBRANCH=$2
else
    GITBRANCH=master
fi

REPO=$(basename $GITURL .git)

if [ ! -d $REPO ];
then
    echo "Repo does not exist we clone it here under the name $REPO"
    git clone "$GITURL"  --branch "$GITBRANCH"
else
    echo "Repo exists we pull $REPO"
    cd ./$REPO
    git pull
fi

