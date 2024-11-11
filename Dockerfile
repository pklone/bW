FROM php:5.6-apache

# probably useless
WORKDIR /var/www/html/

# update DebianStretch sourcelist (see https://wiki.debian.org/DebianStretch#FAQ)
RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y apt-transport-https \
    && sed -i s/http/https/ /etc/apt/sources.list

# install tools
# NOTE: *-dev are required to compile gd module (see https://www.php.net/manual/en/book.image.php in "Requirements" and "Installation")
RUN apt-get install -y \
    libgd-dev \
    libpng-dev \
    libjpeg-dev \
    wget \
    unzip \
    vim

# download and install bWAPP
RUN wget -O bwapp.zip https://sourceforge.net/projects/bwapp/files/bWAPP/bWAPPv2.2/bWAPPv2.2.zip/download \
    && unzip bwapp.zip 'bWAPP/*' \
    && rm bwapp.zip

# install mysql/mysqli modules. The mysql module is required to run
#   SQL Injection (Login Form/Hero)
# and mysqli is used mostly everywhere
RUN docker-php-ext-install \
      mysql \
      mysqli \
    && docker-php-ext-enable mysqli

# install gd module. It is required to run
#   Broken Authentication - CAPTCHA Bypassing
# NOTE: ext-configure AND THEN ext-install,
#       otherwise gd module will not work
RUN docker-php-ext-configure gd \
      --with-png-dir \
      --with-zlib-dir \
      --with-freetype-dir \
      --enable-gd-native-ttf \
    && docker-php-ext-install gd

# useful redirect from root page to bWAPP/login.php
RUN echo '<?php header("Location: http://" . $_SERVER["HTTP_HOST"] . "/bWAPP/login.php"); ?>' > index.php

# change database host
# NOTE: it must be equal to database key under "services" in "compose.yml" (i.e. "db")
RUN sed -i 's|^\($db_server = "\).*\(";\)|\1db\2|' bWAPP/admin/settings.php

# set php.ini file
# NOTE: timezone is necessary otherwise 
#         SQL Injection - Stored (SQLite) 
#         phpinfo.php
#       return a warning
COPY <<-'EOT' /usr/local/bin/bwapp_config_phpini
	#!/bin/sh
	set -e
	
	if [ -n "${BWAPP_PHPINI}" ]; then
		ini="/usr/local/etc/php/php.ini-production"
		symlink="/usr/local/etc/php/php.ini"
		tz=$(cat /etc/timezone)

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
		&& set -- ${bwapp_config_args} apache2-foreground "$@" \
		|| set -- ${bwapp_config_args} "$@"

	exec "$@"
EOT

RUN chmod +x /usr/local/bin/bwapp_*

EXPOSE 80

ENTRYPOINT ["bwapp_entrypoint"]

CMD ["apache2-foreground"]
