#!/usr/bin/env bash
set -e
SCRIPT_PATH=$(readlink -e -- "${BASH_SOURCE[0]}" && echo x) && SCRIPT_PATH=${SCRIPT_PATH%?x}
SCRIPT_DIR=$(dirname -- "$SCRIPT_PATH" && echo x) && SCRIPT_DIR=${SCRIPT_DIR%?x}

: ${DOCKERPUSH_WORKDIR:=/var/www/repos}

#############################################################################################################
# Getopts
#############################################################################################################
while getopts "e:s:" o; do
    case "${o}" in
        e)
            e=${OPTARG}
            ;;
        s)
            s=${OPTARG}
            ;;
		*)
			echo ${OPTARG}
			;;
    esac
done
shift $((OPTIND-1))

if [ -n "$e" ] && [ ! -f "$e" ]; then
	echo "Envfile $e not found"
	exit 1
fi

#############################################################################################################
# Start the Main part of this script
#############################################################################################################
function main () {
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
	REPONAME="$NAME.git"
	WORKTREE="$DOCKERPUSH_WORKDIR"/$NAME
	GITDIR="$SCRIPT_DIR/$REPONAME"
	DOCKERPUSH_DIR="$SCRIPT_DIR/.dockerpush"
	DOCKERPUSH_REPO=$DOCKERPUSH_DIR/$NAME
	HOOKFILE=$REPONAME/hooks/post-receive
	LOGENVFILE=$DOCKERPUSH_REPO/envfile

	#############################################################################################################
	# Display help if help flag is set or number of arguments is wrong
	#############################################################################################################
	if [[ $NAME == "--help" ]] || [ ! -n "$1"  ] || [ ! -n "$2"  ]; then
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
	createDockerpushDir
	createEnvFile
	createWorkTreeDir
	createRepo
	doInitialCommit
	createHook
	createDefaultStrategy
}

function createEnvFile {
    if [ -n "$e" ];
    then
        #############################################################################################################
        # Create env file and make it readable only to root. docker-compose can read it
        #############################################################################################################
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
                echo "master ref received.  Deploying master branch"
                sudo $DOCKERPUSH_DIR/dockerpush-strategy.sh "$NAME"
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

    Usage: ./dockerpush.sh [-e envfile] [-s strategyfile] reponame gituser
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
# Create a initial commit
#############################################################################################################
function doInitialCommit {
    git --work-tree=$WORKTREE --git-dir=$GITDIR checkout -f -b master
    echo "Dockerpush repository" > $WORKTREE/dockerpush.txt
    git --work-tree=$WORKTREE --git-dir=$GITDIR add .
    git --work-tree=$WORKTREE --git-dir=$GITDIR commit -m "Dockperpush init"
    git --work-tree=$WORKTREE --git-dir=$GITDIR remote add origin $GITDIR
    git --work-tree=$WORKTREE --git-dir=$GITDIR push --set-upstream origin master
}

#############################################################################################################
# Create Strategy Script
#############################################################################################################
function createDefaultStrategy {
    cat <<-EOF > "$DOCKERPUSH_DIR/dockerpush-strategy.sh"
        #!/bin/bash
		SCRIPT_PATH=\$(readlink -e -- "\${BASH_SOURCE[0]}" && echo x) && SCRIPT_PATH=\${SCRIPT_PATH%?x}
		SCRIPT_DIR=\$(dirname -- "\$SCRIPT_PATH" && echo x) && SCRIPT_DIR=\${SCRIPT_DIR%?x}
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
        WORKTREE="\$DOCKERPUSH_WORKDIR/\$NAME"
        GITDIR=$SCRIPT_DIR/\$NAME.git
        DOCKERPUSH_REPO=$DOCKERPUSH_DIR/\$NAME
        LOGENVFILE=\$SCRIPT_DIR/\$NAME/envfile

        #############################################################################################################
        # Check for a valid repo created with the dockerpush script
        #############################################################################################################
        if [ ! -d \$DOCKERPUSH_REPO ]; then
            echo "[ERROR] You are not allowed use this strategy on the repository \$NAME"
            exit 1
        fi

        #############################################################################################################
        # Check envfile exists and generate its path in the worktree
        #############################################################################################################
        if [ -f \$LOGENVFILE ]; then
            ENVFILE=\$(head -1 \$LOGENVFILE)
            WORKTREE_ENV=\$WORKTREE/\${ENVFILE##*/}
        else
            ENVIFLE=
        fi

        #############################################################################################################
        # Checkout git repo
        #############################################################################################################

        git --work-tree=\$WORKTREE --git-dir=\$GITDIR checkout -f
        chmod -R  640 \$WORKTREE

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
    chmod 741 "$DOCKERPUSH_DIR"/dockerpush-strategy.sh
}

main $1 $2