app_container_name := "bwapp_app"
db_container_name  := "bwapp_db"

default: up

install: 
	curl http://127.0.0.1:8080/bWAPP/install.php?install=yes

on:
	#!/bin/bash
	if $(systemctl --quiet is-active docker); then
		echo "Docker deamon is already active..."
	else
		echo "Starting docker deamon..."
		sudo systemctl start docker
	fi

off: down
	#!/bin/bash
	read -p "Turn off docker deamon? [Y/n] " res 
	if [ -z "$res" ] || [ "$res" == "Y" ]; then
		sudo systemctl stop docker docker.socket
	fi

up: on
	#!/bin/bash
	if [ $(docker compose ps -q | wc -l) -eq 0 ]; then
		echo "Starting containers..."
		docker compose up -d
	else
		echo "Containers are already running..."
	fi

down:
	#!/bin/bash
	if [ $(docker compose ps -aq | wc -l) -eq 2 ]; then
		echo "Removing containers..."
		docker compose down
	else
		echo "There are no containers..."
	fi

start: on
	#!/bin/bash
	if [ $(docker compose ps -q --status exited | wc -l) -eq 2 ]; then
		echo "Starting containers..."
		docker compose start
	else
		echo "Containers are already running..."
	fi

stop:
	#!/bin/bash
	if [ $(docker compose ps -q | wc -l) -eq 2 ]; then
		echo "Stopping containers..."
		docker compose stop
	else
		echo "Containers are stopped..."
	fi

ps:
	#!/bin/bash
	if $(systemctl --quiet is-active docker); then
		docker compose ps -a
	else
		echo "Docker deamon is stopped."
	fi

@app: up
	echo "Get into {{app_container_name}}..."
	docker exec -it {{app_container_name}} /bin/bash

@db: up
	echo "Get into {{db_container_name}}..."
	docker exec -it {{db_container_name}} /bin/bash

build: on
	docker compose build

config: on
	docker compose config
