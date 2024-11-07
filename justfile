shell := env('SHELL', '/bin/bash')

default: up

install: 
	curl http://127.0.0.1:8080/bWAPP/install.php?install=yes

on:
	#!{{shell}}
	if $(systemctl --quiet is-active docker); then
		echo "Docker deamon is already active..."
	else
		echo "Starting docker deamon..."
		sudo systemctl start docker
	fi

off: down
	#!{{shell}}
	read -p "Turn off docker deamon? [Y/n] " res 
	if [ -z "$res" ] || [ "$res" == "Y" ]; then
		sudo systemctl stop docker docker.socket
	fi

up: on
	#!{{shell}}
	if [ $(docker compose ps -q | wc -l) -eq 0 ]; then
		echo "Starting containers..."
		docker compose up -d
	else
		echo "Containers are already running..."
	fi

down:
	#!{{shell}}
	if [ $(docker compose ps -aq | wc -l) -eq 2 ]; then
		echo "Removing containers..."
		docker compose down
	else
		echo "There are no containers..."
	fi

start: on
	#!{{shell}}
	if [ $(docker compose ps -q --status exited | wc -l) -eq 2 ]; then
		echo "Starting containers..."
		docker compose start
	else
		echo "Containers are already running..."
	fi

stop:
	#!{{shell}}
	if [ $(docker compose ps -q | wc -l) -eq 2 ]; then
		echo "Stopping containers..."
		docker compose stop
	else
		echo "Containers are stopped..."
	fi

ps:
	#!{{shell}}
	if $(systemctl --quiet is-active docker); then
		docker compose ps -a
	else
		echo "Docker deamon is stopped."
	fi

exec: up
	#!{{shell}}
	if ! command -v jq &>/dev/null; then
	    echo "Error: jq not found"
		exit 0
	fi
	
	containers=$(docker compose ps --format json | jq -rs 'map(.Name) | @sh // empty' | tr -d \')
	if [ -n "$containers" ]; then
		if ! command -v fzf &>/dev/null; then
			select container_name in $containers;
			do
				if [ $REPLY -ge 1 ] && [ $REPLY -le $(echo $containers | wc -w) ]; then
					break
				fi
			done
		else
			container_name=$(echo -n "$containers" \
				| tr ' ' '\n' \
				| fzf --exact --reverse --border --header-first --header "ESC. quit")
		fi
		
		if [ -z "${container_name}" ]; then
			echo "Error: no container selected"
			exit 1
		fi

		echo "Getting into ${container_name}..."
		docker exec -it "${container_name}" /bin/bash
	else
		echo "No container available"
	fi

build: on
	docker compose build

config: on
	docker compose config
