#!/usr/bin/env bash
set -e

: ${DOCKERPUSH_WORKDIR:=/var/www/repos}

while getopts ":e:s:" o; do
    case "${o}" in
        e)
            e=${OPTARG}
            ;;
        s)
            s=${OPTARG}
            ;;
    esac
done

#############################################################################################################
# Script must be executed as superuser
#############################################################################################################
if ! [ $(id -u) = 0 ]; then
   echo "This script must be called as root or with sudo"
   exit 1
fi

#############################################################################################################
# Setup vars
#############################################################################################################
NAME="$1"
USER="$2"
CURRENTDIR="$PWD"
REPONAME="$NAME.git"
WORKTREE="$DOCKERPUSH_WORKDIR"/$NAME
GITDIR="$CURRENTDIR/$REPONAME"
DOCKERPUSH_DIR=".dockerpush"
DOCKERPUSH_REPO=$DOCKERPUSH_DIR/$NAME
HOOKFILE=$REPONAME/hooks/post-receive
LOGENVFILE=$DOCKERPUSH_REPO/envfile

#############################################################################################################
# Display help if help flag is set or number of arguments is wrong
#############################################################################################################
if [[ $NAME == "--help" ]] || [ "$#" -lt "2" ] || [ "$#" -gt "3" ]; then
    showHelp
    exit 0
fi

#############################################################################################################
# Check if the given user does exist
#############################################################################################################
if ! id -u "$2" >/dev/null 2>&1; then
    echo "The given user $2 does not exist"
    exit 1
fi

#############################################################################################################
# Create all this stuff. Be careful with the order of execution
#############################################################################################################
createEnvFile
createDockerpushDir
createWorkTreeDir
createRepo
createHook
createDefaultStrategy

#############################################################################################################
# Set branch if given else set to master
#############################################################################################################


function createEnvFile {
    if [ $e ];
    then
        #############################################################################################################
        # Create env file and make it readable only to root. docker-compose can read it
        #############################################################################################################
        touch "$e"
        # Get full path
        ENVFILE=$(readlink -f $e)
        echo $ENVFILE > $LOGENVFILE
        chmod 640 $LOGENVFILE
        chmod 640 $ENVFILE
    else
        ENVFILE=""
    fi
}
#############################################################################################################
# Create hook script
#############################################################################################################
function createHook {

    cat <<-EOF > $HOOKFILE
        #!/bin/bash

        while read oldrev newrev ref
        do
            echo "Post Receive Hook ..."
            if [[ \$ref =~ .*/master$ ]];
            then
                echo "master ref received.  Deploying master branch to production..."
                sudo ./dockerpush-strategy.sh "$NAME"
                exit 0
            else
                echo "Ref \$ref successfully received.  Doing nothing: only the master branch may be deployed on this Repo."
            fi
            exit 1
        done
EOF
    chmod +x $HOOKFILE
}


#############################################################################################################
# HELP TEXT
#############################################################################################################

function showHelp {
    echo '
    This script must be allowed to create files in this dir and in the dockerpush worktree dir.
    Also it must be allowed to call git init and docker-compose up -d and docker-compose build

    Set environment DOCKERPUSH_WORKDIR to a path where the work dirs should be placed else it defaults to /var/www/repos

    [ENVFILE] Set the path to an file. This file will be symlinked to the workdir root.

    Usage: dockerpush.sh reponame gituser [-e envfile] [-s strategyfile]
    '
}

#############################################################################################################
# Create the dockerpush dir if it does not exist and creagted the repo name. This will delete the old repo
#############################################################################################################
function createDockerpushDir {
    if [ ! -d $DOCKERPUSH_DIR ];then
        mkdir  $DOCKERPUSH_DIR
        chmod 640 $DOCKERPUSH_DIR
    fi
    if [ -d $DOCKERPUSH_REPO ]; then
        rm -rf $DOCKERPUSH_REPO
    fi
    mkdir $DOCKERPUSH_REPO
    chmod 640 $DOCKERPUSH_REPO
}

#############################################################################################################
# Creates the worktree dir
#############################################################################################################
function createWorkTreeDir {

    if [ -d $WORKTREE ]; then
        rm -rf $WORKTREE;
    fi

    mkdir -p $WORKTREE
    chmod 640 $WORKTREE
}
#############################################################################################################
# Create the repo folder and inits a bare repository
#############################################################################################################
function createRepo {
    if [ -d $REPONAME ]; then
        rm -rf $REPONAME;
    fi
    mkdir $REPONAME

    git init --bare $REPONAME
    chown -R $USER:$USER $REPONAME
}
#############################################################################################################
# Create Strategy Script
#############################################################################################################
function createDefaultStrategy {
    if [ -f "$DOCKERPUSH_DIR/dockerpush-strategy.sh" ]; then
        return
    fi
    cat <<-EOF > "$DOCKERPUSH_DIR/dockerpush-strategy.sh"
        #!/bin/bash
        #############################################################################################################
        # This script must be called with sudo
        # usage: ./dockerpush-strategy.sh reponame
        #
        # reponame without .git extension
        #############################################################################################################

        #############################################################################################################
        # Script must be executed as superuser
        #############################################################################################################
        if ! [ \$(id -u) = 0 ]; then
           echo "This script must be called as root or with sudo"
           exit 1
        fi

        #############################################################################################################
        # Vars
        #############################################################################################################
        : \${DOCKERPUSH_WORKDIR:=/var/www/repos}

        NAME="\$1"
        REPONAME=\$NAME.git
        WORKTREE="\$DOCKERPUSH_WORKDIR/\$NAME"
        GITDIR=$CURRENTDIR/\$REPONAME
        DOCKERPUSH_REPO=$DOCKERPUSH_DIR/\$NAME
        LOGENVFILE=\$DOCKERPUSH_REPO/envfile

        #############################################################################################################
        # Check for a valid repo created with the dockerpush script
        #############################################################################################################
        if [ -d \$DOCKERPUSH_REPO ]; then
            echo "[ERROR] You are not allowed use this strategy on the repository \$NAME"
            exit 1
        fi

        #############################################################################################################
        # Check if a lock file was written
        #############################################################################################################
        if [ -f \$LOGENVFILE ]; then
            ENVFILE=\$(read -r FIRSTLINE < \$LOGENVFILE)
            WORKTREE_ENV=\$WORKTREE/\$(basename \$ENVFILE)
        else
            ENVIFLE=
        fi

        #############################################################################################################
        # Checkout git repo
        #############################################################################################################
        git --work-tree=\$WORKTREE --git-dir=\$GITDIR checkout -f

        #############################################################################################################
        # Execute docker-compose
        #############################################################################################################
        if [ -f \$WORKTREE/docker-compose.yml ];
        then
            #############################################################################################################
            # Link env file in to worktree forceful
            #############################################################################################################
            if [ -f \$ENVFILE ];then
                ln -sf \$ENVFILE \$WORKTREE_ENV
            fi
            cd \$WORKTREE
            docker-compose build
            docker-compose up -d
            exit 0
        else
             echo "Could not find docker-compose.yml"
             exit 1
        fi
EOF
    chmod 640 dockerpush-strategy.sh
}