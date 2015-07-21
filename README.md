# Dockerinstall

Is a simple script to manage docker installs from git
Instead of pushing repos like Dokku we use pulling. Which is easier and works better with our CI tool Wercker

## Prequesite

The public ssh key of the user must be placed in the repo

## Usage
Place this script in your users home folder and make it executable:

```wget -N https://bitbucket.org/schnueggel/dockerinstall/raw/f58bdd566b2b366d15e69d5c2cf03d55d89517f7/dockerinstall.sh```

```chmod u+x ./dockerinstall.sh```

Then call:

```sudo ./dockerinstall.sh mygit.repourlurl```

This will create a new folder under the reponame (Git clone). If the repo already exists it will make a git pull.

This script must be called with sudo. Allow the user to call this script with sudo and without password if you want to ssh to this script.

To do this type ```visudo``` and add the following line for example:

```myuser ALL=(root) NOPASSWD: /home/myuser/dockerinstall```

