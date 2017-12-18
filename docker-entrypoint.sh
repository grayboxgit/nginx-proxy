#!/bin/bash
set -e

# Warn if the DOCKER_HOST socket does not exist
if [[ $DOCKER_HOST = unix://* ]]; then
	socket_file=${DOCKER_HOST#unix://}
	if ! [ -S $socket_file ]; then
		cat >&2 <<-EOT
			ERROR: you need to share your Docker host socket with a volume at $socket_file
			Typically you should run your jwilder/nginx-proxy with: \`-v /var/run/docker.sock:$socket_file:ro\`
			See the documentation at http://git.io/vZaGJ
		EOT
		socketMissing=1
	fi
fi

# Generate dhparam file if required
# Note: if $DHPARAM_BITS is not defined, generate-dhparam.sh will use 2048 as a default
/app/generate-dhparam.sh $DHPARAM_BITS

# Compute the DNS resolvers for use in the templates
export RESOLVERS=$(awk '$1 == "nameserver" {print $2}' ORS=' ' /etc/resolv.conf | sed 's/ *$//g')
if [ "x$RESOLVERS" = "x" ]; then
    echo "Warning: unable to determine DNS resolvers for nginx" >&2
    unset RESOLVERS
fi

if [ ! -f /etc/nginx/certs/dev.crt ]; then
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/dev.key -out /etc/nginx/certs/dev.crt \
		-subj "/C=US/ST=Oregon/L=Portland/O=Docker Proxy/OU=None/CN=*.dev"
fi

if [ ! -f /etc/nginx/certs/test.crt ]; then
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/test.key -out /etc/nginx/certs/test.crt \
		-subj "/C=US/ST=Oregon/L=Portland/O=Docker Proxy/OU=None/CN=*.test"
fi

if [ ! -f /etc/nginx/certs/local.crt ]; then
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/certs/local.key -out /etc/nginx/certs/local.crt \
		-subj "/C=US/ST=Oregon/L=Portland/O=Docker Proxy/OU=None/CN=*.local"
fi

# If the user has run the default command and the socket doesn't exist, fail
if [ "$socketMissing" = 1 -a "$1" = forego -a "$2" = start -a "$3" = '-r' ]; then
	exit 1
fi

exec "$@"
