#!/usr/bin/env bash
set -e

: ${DOCKERPUSH_WORKDIR:=/var/www/repos}

#############################################################################################################
# HELP TEXT
#############################################################################################################
HELP='
This script must be allowed to create files in this dir and in the dockerpush worktree dir.
Also it must be allowed to call git init and docker-compose up -d and docker-compose build

Set environment DOCKERPUSH_WORKDIR to a path where the work dirs should be placed else it defaults to /var/www/repos

[ENVFILE] Set the path to an file. this file will be copied to the workdir root.
Usage:

dockerpush.sh reponame [ENVFILE]
';

REPONAME=$1
#############################################################################################################
# Display help if help flag is set or number of arguments is wrong
#############################################################################################################
if [[ $REPONAME == "--help" ]] || [ "$#" -lt "1" ] || [ "$#" -gt "2" ]; then
    echo "$HELP"
    exit 0
fi

#############################################################################################################
# Set branch if given else set to master
#############################################################################################################
if [ $# -eq 2 ];
then
    ENVFILE=$2
    touch ENVFILE
else
    ENVFILE=""
fi

CURRENTDIR="$PWD"
REPONAME="$1.git";
WORKTREE="$DOCKERPUSH_WORKDIR/$1"
GITDIR="$CURRENTDIR/$REPONAME"

if [ -d "$REPONAME" ]; then
    rm -rf $REPONAME;
fi

if [ -d "$WORKTREE" ]; then
    rm -rf $WORKTREE;
fi

mkdir -p $WORKTREE
sudo chown -R `whoami`:`id -gn` "$WORKTREE"

#############################################################################################################
# Create bare repo without work tree.
#############################################################################################################

mkdir "$REPONAME" && cd "$REPONAME";

git init --bare
cd hooks;

#############################################################################################################
# Create hook script
#############################################################################################################
cat <<EOF > post-receive
#!/bin/sh

while read oldrev newrev ref
do
    echo "Post Receive Hook ..."
    if [[ \$ref =~ .*/master$ ]];
    then
        echo "master ref received.  Deploying master branch to production..."
        git --work-tree="$WORKTREE" --git-dir="$GITDIR" checkout -f
        if [ -f "$WORKTREE/docker-compose.yml" ];
        then
            if [ -f "$ENVFILE" ];then
                cp "$ENVFILE" "$WORKTREE/"
            fi
            cd $WORKTREE
            sudo -E docker-compose build
            sudo -E docker-compose up -d
        else
             echo "Could not find docker-compose.yml"
        fi
    else
        echo "Ref \$ref successfully received.  Doing nothing: only the master branch may be deployed on this Repo."
        exit 1
    fi
done
EOF

chmod +x post-receive