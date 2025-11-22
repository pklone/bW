set dotenv-load

command_std := '/bin/bash'
command_app := command_std
command_db  := 'mysql -u root'

alias rs := restart

_default:
	@just --list --unsorted

_install: 
	curl http://127.0.0.1:8080/bWAPP/install.php?install=yes

[private]
run:
	@just --choose --unsorted

# start docker daemon
on:
	#!/bin/bash
	if ! $(systemctl --quiet is-active docker); then
		echo "Starting docker deamon..."
		sudo systemctl start docker
	fi

# stop docker daemon
off: down
	#!/bin/bash
	read -p "Turn off docker deamon? [Y/n] " res 
	if [ -z "$res" ] || [ "$res" == "Y" ]; then
		sudo systemctl stop docker docker.socket
	fi

# run containers
[positional-arguments]
up *args='-d': on
	#!/bin/bash
	if [ $(docker compose ps -q | wc -l) -eq 0 ]; then
		echo "Starting containers..."
		docker compose up $@
	else
		echo "Containers are already running..."
	fi

# kill containers
[positional-arguments]
down *args='':
	#!/bin/bash
	if [ $(docker compose ps -aq | wc -l) -ne 0 ]; then
		echo "Removing containers..."
		docker compose down $@
	else
		echo "There are no containers..."
	fi

# kill, re-build and run containers
@restart:
	just down && just build && just up

# start containers (if they're stopped) 
start: on
	#!/bin/bash
	if [ $(docker compose ps -q --status exited | wc -l) -ne 0 ]; then
		echo "Starting containers..."
		docker compose start
	else
		echo "Containers are already running..."
	fi

# stop containers (if they're running)
stop:
	#!/bin/bash
	if [ $(docker compose ps -q | wc -l) -ne 0 ]; then
		echo "Stopping containers..."
		docker compose stop
	else
		echo "Containers are stopped..."
	fi

# show running/stopped containers info
ps all='':
	#!/bin/bash
	if $(systemctl --quiet is-active docker); then
		[ -z "{{ all }}" ] \
			&& docker compose ps -a \
			|| docker ps -a
	else
		echo "Docker deamon is stopped."
	fi

# run a command inside a container
[positional-arguments]
exec *args='': up
	#!/bin/bash

	if ! command -v jq &>/dev/null; then
	    echo "Error: jq not found"
		exit 0
	fi

	containers=$(docker compose ps --format json \
		| jq -rs 'map(.Name) | @sh // empty' \
		| tr -d \')
	
	if [ -z "$containers" ]; then
		echo "Error: no container available"
		exit 1
	fi

	if [ -z "${EXEC_RECIPE_CHOOSER}" ]; then
		select container_name in $containers;
		do
			if [ $REPLY -ge 1 ] && [ $REPLY -le $(echo $containers | wc -w) ]; then
				break
			fi
		done
	else
		container_name=$(echo -n "$containers" \
			| tr ' ' '\n' \
			| bash -c "${EXEC_RECIPE_CHOOSER}")
	fi
	
	if [ -z "${container_name}" ]; then
		echo "Error: no container selected"
		exit 1
	fi

	if [ -n "$1" ]; then 
		command="$@"
	else
		case "${container_name#*_}" in
			app)
				command="{{command_app}}"
				;;
			db)
				command="{{command_db}}"
				;;
			*)
				command="{{command_std}}"
				;;
		esac
	fi

	echo "Getting into ${container_name}..."
	docker exec -it "${container_name}" $command

# build images
@build: on
	docker compose build

# return compose.yml file in canonical form
@config: on
	docker compose config
