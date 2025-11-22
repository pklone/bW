FROM debian:trixie AS keyring

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /keyring

# install gpg and other tools
# NOTE: ca-certificates is an optional dependency of wget. Without it, wget cannot trust keyserver.ubuntu.com certificate.
#       However, since ca-certificates is optional, --no-install-recommends will skip it, so we need to install it explicitly
RUN apt-get update && apt-get install -y --no-install-recommends \
	wget \
	ca-certificates \
	gnupg2 

# download DEB.SURY.ORG Automatic Signing Key (see https://deb.sury.org)
RUN wget -O- 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x15058500a0235d97f5d10063b188e2b695bd4743' \
	| gpg --dearmor > ppa-ondrej-php-archive-keyring.pgp

# .gpg symbolic link to .pgp
RUN ln -s ppa-ondrej-php-archive-keyring.pgp ppa-ondrej-php-archive-keyring.gpg


FROM httpd:trixie

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /usr/local/apache2/htdocs

# multi-stage building
COPY --from=keyring /keyring/ppa-ondrej-php-archive-keyring.* /usr/share/keyrings/

# install tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    unzip \
    vim \
	curl \
	less

# update apt sourcelist to include deb.sury.org repository
RUN cat <<-'EOT' >> /etc/apt/sources.list.d/debian.sources
	
	Types: deb
	URIs: https://packages.sury.org/php
	Suites: trixie
	Components: main
	Signed-By: /usr/share/keyrings/ppa-ondrej-php-archive-keyring.pgp

EOT

# install php5.6
# NOTE: gd module is required to run
# 	Broken Authentication - CAPTCHA Bypassing
RUN apt-get update && apt-get install -y --no-install-recommends \
	php5.6 \
	php5.6-common \
	php5.6-mysql \
	php5.6-gd

# enable php in apache config file
RUN cat <<-'EOT' >> /usr/local/apache2/conf/httpd.conf

	LoadModule php5_module /usr/lib/apache2/modules/libphp5.6.so
	Include /etc/apache2/mods-available/php5.6.conf

EOT

# solve 'Apache is running a threaded MPM, but your PHP Module is not compiled to be threadsafe' error.
# (see https://stackoverflow.com/questions/77101606/running-php-in-docker-container-httpdlatest)
RUN sed -i /usr/local/apache2/conf/httpd.conf \
	-e 's|^\(LoadModule mpm_event_module modules/mod_mpm_event.so\)$|#\1|' \
	-e 's|^#\(LoadModule mpm_prefork_module modules/mod_mpm_prefork.so\)$|\1|'

# add index.php as the default file that the server will serve when a directory is requested
RUN sed -i 's|^\(\s*DirectoryIndex\).*$|\1 index.php index.html|' /usr/local/apache2/conf/httpd.conf

# setting ServerName so that Apache does not complain
RUN sed -i 's|^#\?\(ServerName\) .\+$|\1 localhost|' /usr/local/apache2/conf/httpd.conf

# download and install bWAPP
RUN wget -O bwapp.zip https://sourceforge.net/projects/bwapp/files/bWAPP/bWAPPv2.2/bWAPPv2.2.zip/download \
    && unzip bwapp.zip 'bWAPP/*' \
    && rm bwapp.zip

# useful redirect from root page to bWAPP/login.php and delete index.html (if it exists)
RUN echo '<?php header("Location: http://" . $_SERVER["HTTP_HOST"] . "/bWAPP/login.php"); ?>' > index.html \
	&& mv index.html index.php

# change database host
# NOTE: it must be equal to database key under "services" in "compose.yml" (i.e. "db")
RUN sed -i 's|^\($db_server = "\).*\(";\)|\1db\2|' bWAPP/admin/settings.php

# change owner from 'root' to 'www-data'
RUN chown -R www-data:www-data bWAPP/ index.php

# set php.ini file
# NOTE: timezone is necessary otherwise 
#         SQL Injection - Stored (SQLite) 
#         phpinfo.php
#       return a warning
COPY <<-'EOT' /usr/local/bin/bwapp_config_phpini
	#!/bin/sh
	set -e
	
	if [ -n "${BWAPP_PHPINI}" ]; then
		ini="/usr/lib/php/5.6/php.ini-production"
		symlink="/usr/lib/php/5.6/php.ini"
		tz=$(date +%Z)

		ln -s "$ini" "$symlink"
		sed -i "s|;\(date\.timezone =\)|\1 \"$tz\"|" "$symlink"
	fi

	exec "$@"
EOT

# "More fun" mode
COPY <<-'EOT' /usr/local/bin/bwapp_config_fun
	#!/bin/sh
	set -e
	
	if [ -n "${BWAPP_MORE_FUN}" ]; then
		chmod 777 bWAPP/passwords/
		chmod 777 bWAPP/images/
		chmod 777 bWAPP/documents/
		
		if [ -d /bWAPP/logs ]; then
			chmod 777 bWAPP/logs/
		fi
	fi
	
	exec "$@"
EOT

# add custom challenges
COPY <<-'EOT' /usr/local/bin/bwapp_config_custom
	#!/bin/sh
	set -e

	if [ -n "${BWAPP_CUSTOM_CHALLS}" ]; then	
		challenges=$(find /tmp/custom_challs -type f -name '*.php' -printf '%p\n' \
			| sort -r \
			| sed 's|.*/\(.*\)\.\(php\)|\1,\1.\2|' \
		)
		
		if [ -n "$challenges" ]; then
			cp -t bWAPP/ /tmp/custom_challs/*.php
			
			echo -ne \
				'\n---------------------------  Custom  --------------------------,portal.php' \
				"\n$challenges" \
			>> bWAPP/bugs.txt
		fi
	fi
	
	exec "$@"
EOT

# update entrypoint
COPY <<-'EOT' /usr/local/bin/bwapp_entrypoint
	#!/bin/sh
	set -e

	bwapp_config_args=$(find /usr/local/bin/ -type f -name 'bwapp_config_*' -printf '%P ')

	# first arg is `-f` or `--some-option`
	[ "${1#-}" != "$1" ] \
		&& set -- ${bwapp_config_args} httpd-foreground "$@" \
		|| set -- ${bwapp_config_args} "$@"

	exec "$@"
EOT

RUN chmod +x /usr/local/bin/bwapp_*

EXPOSE 80

ENTRYPOINT ["bwapp_entrypoint"]

CMD ["httpd-foreground"]
