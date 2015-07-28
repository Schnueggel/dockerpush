# Dockerpush

Is a simple script to manage docker installs with git and docker-compose on bare metal instances

## Prequesite

The public ssh key of your gituser must be placed in the authorized keys file.

Docker and docker-compose must be installed.

sudo 

See also [Git Hook](#githook)

## Usage
Place this script in your git users home folder and make it executable:

```wget -N https://bitbucket.org/schnueggel/dockerpush/raw/master/dockerpush.sh```

```chmod u+x ./dockerpush.sh```

Then call:

```sudo ./dockerpush.sh myreponame gituser -e composerenvfile.env```

This script must be called with sudo or as root.

This will create a new bare repository with the name "myreponame.git" in the current folder. 
If the repository exist it will be destroyed and recreated. Example:

```
cd /home/gituser 
```

```
wget -N https://bitbucket.org/schnueggel/dockerpush/raw/master/dockerpush.sh
```

```
chmod u+x ./dockerpush.sh
```

```
sudo ./dockerpush.sh myapp gituser -e myapp.env
```

Will generate a folder:

home

-- gituser

---- myapp.git 

------ hooks

-------- post-receive
        
And the worktree dir:

```
/var/www/repos/myapp
```

Later when you push into the repository the myapp.env will be symlinked into the worktree dir:

-- var

---- www

------ repos

-------- myapp

---------- myapp.env

The worktree and the data inside cannot be modified or read by the git user


### dockerpush-strategy.sh

This file will be generated on the first run of dockerpush.sh inside the .dockerpush directory which will also generated.
Those files cannot be read or modified by the gituser.

### EnvFile

If a envfile path was given, the post receive hook will symlink this file into the generated worktree folder. 
So in your docker-compose.yml there should be something like:

```yaml
env_file: ./composerenvfile.env
```

The EnvFile will be set to readable for the root user. The gituser will not be able to read it. docker-compose will be running as root and can read it.
This is enough.

### <a name="githook"></a> Git hook
The generated git hook calls ```docker-compose build``` and ```docker-compose up -d``` on the worktree if it contains a docker-compose.yml

#### Prequesite
To make this work type ```visudo``` and add the following line for example:

```gituser ALL=(root) NOPASSWD: /home/gituser/.dockerpush/dockerpush-strategy.sh```

### Git push

To push to this repository you need a ssh access for the git user to this server
You should use forceful push.

Add a new remote repository destination to your local repository with:

```
git remote add deploy repouser@myrepos.com
```

Create a commit ( Add a file version txt file or something):

```
git commit -m "New Version"
```
--allow-empty flag on commits will fail when pushed to an empty remote repo

Next deploy  what ever local branch you are to the master branch of your repo
```
git push -f deploy HEAD:master
```

### Hint
If you want to push from your local repo to the dockerpush repo make a new branch and call it deploy.
Build your application and add the build result with ```git add .``` to your repository then use git push like described above. 
Be aware of your gitingore file. gitignore files are global and not per branch. Best use a CI Tool.


### TODO

Lock if docker-compose is already running on multiple pushs?

Prompt before delete of directories