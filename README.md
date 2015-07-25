# Dockerpush

Is a simple script to manage docker installs from git

## Prequesite

The public ssh key of the gituser must be placed in the authorized keys.

docker and docker-compose must be installed.

## Usage
Place this script in your users home folder and make it executable:

```wget -N https://bitbucket.org/schnueggel/dockerpush/raw/master/dockerpush.sh```

```chmod u+x ./dockerpush.sh```

Then call:

```sudo ./dockerpush.sh reponame gituser composerenvfile.env```

This script must be called with sudo or as root.

This will create a new folder reponame in the current folder and extend the folder with .git. 
If the repo exist it will be destroyed and recreated. Example:

```
cd ~ 
```

```
wget -N https://bitbucket.org/schnueggel/dockerpush/raw/master/dockerpush.sh
```

```
chmod u+x ./dockerpush.sh
```

```
sudo ./dockerpush.sh myapp git myapp.env
```

Will generate a folder:

~/myapp.git <br>
--- hooks <br>
------ post-receive
        
And the worktree dir:

/var/www/repos/myapp


### EnvFile

If a envfile path was given, the post receive hook will symlink this file into the generated worktree folder. 
So in your docker-compose.yml there should be something like:

```yaml
env_file: ./composerenvfile.env
```

The EnvFile will be set to readable for the root user. The gituser will not be able to read it. docker-compose will be running as root and can read it.
This is enough.

### Git hook
The generated git hook calls ```docker-compose build``` and ```docker-compose up -d``` on the worktree if it contains a docker-compose.yml

To make this work type ```visudo``` and add the following line for example:

```gituser ALL=(root) NOPASSWD: /usr/local/bin/docker-compose```

### Git push

To push to this repository you need a ssh access for the git user to this server
You should use forceful push.

Add the repository destination to your remote

```
git remote add deploy repouser@myrepos.com
```

Create a commit:

```
git commit --allow-empty -m "New Version"
```

Next deploy  what ever local branch you are to the master branch of your repo
```
git push deploy HEAD:master
```

### Hint
If you want to push from your local repo to the dockerpush repo make a new branch and call it deploy.
Build your application and add the build result with ```git add .``` to your repository then use git push like described above. 
Be aware of your gitingore file. gitignore files are global and not per branch. Best use a CI Tool.