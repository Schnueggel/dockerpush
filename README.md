# Dockerinstall

Is a simple script to manage docker installs from git
Instead of pushing repos like Dokku we use pulling. Which is easier and works better with our CI tool Wercker

## Prequesite

The public ssh key of the user must be placed in the repo

## Usage
Place this script in your users home folder and make it executable:

```wget https://bitbucket.org/schnueggel/dockerinstall/raw/5d74d4dfd7b13c6f2c82b867650838005e6ba37b/dockerinstall.sh```

```chmod u+x ./dockerinstall.sh```

Then call:

```sudo ./dockerinstall.sh mygit.repourlurl```

This will create a new folder under the reponame (Git clone). If the repo already exists it will make a git pull.

This script must be called with sudo. Allow the user to call this script with sudo and without password if you want to ssh to this script.

To do this type ```visudo``` and add the following line for example:

```myuser ALL=(root) NOPASSWD: /home/myuser/dockerinstall```

