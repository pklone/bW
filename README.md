# bW - Docker for bWAPP without LAMP
A Docker setup for bWAPP based on `php-5.6` and `mysql-5.5`.

## Additional features
- Redirect from root page to `install.php`
- Add (and browse) custom challenges easily
- `More fun` mode on/off (see [install.txt](https://github.com/jehy-security/bwapp/blob/master/INSTALL.md))
- Configurable `php.ini` file

## Quickstart
Firstly, build the `bwapp` image.
```
docker compose build
```
Then, you can run the containers.
```
docker compose up -d
````
You can also do everything with one command.
```
docker compose up -d --build
```
Browse to `127.0.0.1:8080`, which will redirect you to `install.php`. Create the database, move to `login.php` and log-in as `bee` user (with password `bug`). 

## Advanced
### Database

> [!IMPORTANT]
> If you need to change `db` key under `services` in `compose.yml`, remember also to update the Dockerfile. 
> 
>     RUN sed -i 's|^\($db_server = "\).*\(";\)|\1<key>\2|' bWAPP/admin/settings.php
By default, database is stored inside a local volume, so it is **persisted**. If you want to query the database, use
```
docker exec -it bwapp_db mysql -u root
```
If the db root password defined in `compose.yml` is **not** empty, then you need to add `-p` flag.

Here some useful commands to interact with db.
```
show databases;
use <db_name>;
show tables;
```

### Custom challenges
If you want to add other challenges, make sure `BWAPP_CUSTOM_CHALLS` is not empty. Then, create a directory `custom` and add your php files to it. 

> [!NOTE]
> Inside the container, all the challenges (i.e. bwapp challenges and custom ones) will be in the same directory. 

### Setup files
`bwapp_app` container uses 3 different bash files to setup the app, i.e.
```
bwapp_config_fun       # fun mode setup
bwapp_config_custom    # custom challenges setup 
bwapp_config_phpini    # php.ini setup
```
If you need to add a setup file, follow this template.
```
COPY <<-'EOT' /usr/local/bin/bwapp_config_<name>
	# ...
	exec "$@"
EOT
```
You can also define a new environment variable if you want to enable/disable the new setup file without rebuild the image.

## Tips
### just
You can also use [just](https://github.com/casey/just) to run docker commands. The following commands are available.
```
install    # initialize bWAPP database
on         # turn on docker daemon
off        # turn off docker daemon
up         # run containers
down       # kill containers 
start      # start containers
stop       # stop containers
ps         # get stopped/running containers info
exec       # run a shell inside a container
build      # build docker images
config     # resolve compose.yml in canonical form
```
In particular, `just exec` will open a menu using `fzf` or the bash built-in menu feature `select`. Then, you can select a specific container. 
See the `justfile` for more info.

### Build
You can build `bwapp` image without downloading the Dockerfile.
```
docker build github.com/pklone/bW -t bwapp
```

## Tested challenges

| Challenge                                    | Low | Medium | High |
| -------------------------------------------- | --- | ------ | ---- |
| Broken Authentication - CAPTCHA bypassing    | yes | /      | /    |
| Broken Authentication - Insecure Login Forms | /   | yes    | /    |
| Broken Authentication - Password Attacks     | /   | yes    | /    |
| Broken Authentication - Weak Passwords       | yes | /      | /    |
| SQL Injection (GET/Search)                   | yes | /      | /    |
| SQL Injection (Login Form/Hero)              | yes | /      | /    |
| SQL Injection - Blind - Boolean-Based        | yes | /      | /    |
