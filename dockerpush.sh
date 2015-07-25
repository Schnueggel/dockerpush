#!/usr/bin/env bash
set -e

: ${DOCKERPUSH_WORKDIR:=/var/www/repos}

if ! [ $(id -u) = 0 ]; then
   echo "This script must be called as root or with sudo"
   exit 1
fi

#############################################################################################################
# HELP TEXT
#############################################################################################################
HELP='
This script must be allowed to create files in this dir and in the dockerpush worktree dir.
Also it must be allowed to call git init and docker-compose up -d and docker-compose build

Set environment DOCKERPUSH_WORKDIR to a path where the work dirs should be placed else it defaults to /var/www/repos

[ENVFILE] Set the path to an file. this file will be copied to the workdir root.

Usage:

dockerpush.sh reponame gituser [ENVFILE]
';

REPONAME=$1
#############################################################################################################
# Display help if help flag is set or number of arguments is wrong
#############################################################################################################
if [[ $REPONAME == "--help" ]] || [ "$#" -lt "2" ] || [ "$#" -gt "3" ]; then
    echo "$HELP"
    exit 0
fi

if ! id -u "$2" >/dev/null 2>&1; then
    echo "The given user $2 does not exist"
    exit 1
fi
#############################################################################################################
# Set branch if given else set to master
#############################################################################################################
if [ $# -eq 3 ];
then
    #############################################################################################################
    # Create env file and make it readable only to root. docker-compose can read it
    #############################################################################################################
    touch $3
    chmod o-r $3
    ENVFILE=$(readlink -f $3)
else
    ENVFILE=""
fi
USER=$2
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
chown -R "$USER":"$USER" "$WORKTREE"

#############################################################################################################
# Create bare repo without work tree.
#############################################################################################################

mkdir "$REPONAME"

cd "$REPONAME";

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
                cp -f "$ENVFILE" "$WORKTREE/"
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

cd ..
cd ..

chown -R "$USER":"$USER" "$REPONAME"