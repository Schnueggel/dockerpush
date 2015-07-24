#!/usr/bin/env bash
set -e

: ${DOCKERPUSH_WORKDIR:=/var/www/repos}


HELP='
This script must be allowed to create files in this dir and in the dockerpush worktree dir.
Also it must be allowed to call git init and docker-compose up -d and docker-compose build

Set environment DOCKERPUSH_WORKDIR to a path where the work dirs should be placed else it defaults to /var/www/repos

Usage:

dockerpush.sh reponame [branch=master]
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
# Make the user of this script owns the repo dir
#############################################################################################################
mkdir -p "$DOCKERPUSH_WORKDIR"
sudo chown -R `whoami`:`id -gn` "$DOCKERPUSH_WORKDIR"

#############################################################################################################
# Set branch if given else set to master
#############################################################################################################
if [ $# -eq 2 ];
then
    BRANCH=$2
else
    BRANCH=master
fi

CURRENTDIR="$PWD"
REPONAME="$1.git";
WORKTREE="$DOCKERPUSH_WORKDIR/$1"
GITDIR="$CURRENTDIR/$REPONAME"

if [ -d "$REPONAME" ]; then
    echo "Repository $REPONAME already exist";
    exit 0;
fi

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
    echo "Post Receive Hook..."
    if [[ '$ref' =~ .*/$BRANCH$ ]];
    then
        echo "$BRANCH ref received.  Deploying $BRANCH branch to production..."
        git --work-tree="$DOCKERPUSH_WORKDIR" --git-dir="$GITDIR" checkout -f
        if [ -f "$WORKTREE/docker-compose.yml" ];
        then
            docker-compose build
            docker-compose up -d
        else
             echo "Could not find docker-compose.yml"
        fi
    else
        echo "Ref '$ref' successfully received.  Doing nothing: only the $BRANCH branch may be deployed on this Repo."
        exit 1
    fi
done
EOF

chmod +x post-receive