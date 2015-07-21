# Dockerinstall

Is a simple script to manage docker installs from git
Instead of pushing repos we use pulling. Which is easier and works better with our CI tool wercker

## Prequesite

The public ssh key of the user must be placed in the repo

## Usage
Place this script in your users home folder and make it executable

install.sh mygit.repourlurl

this will create a new folder under the reponame. (Git clone) If the repo already exists it will make a git pull

This script must be called with sudo. Allow the user to call this script with sudo and without password.