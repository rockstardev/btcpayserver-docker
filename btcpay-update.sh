#!/bin/bash

set -e

. /etc/profile.d/btcpay-env.sh

cd "$BTCPAY_BASE_DIRECTORY/btcpayserver-docker"  
git pull --force
# Generate the docker compose in BTCPAY_DOCKER_COMPOSE
#. ./build.sh

for scriptname in *.sh; do
    if [ "$scriptname" == "build.sh" -o "$scriptname" == "build-pregen.sh" ] ; then
        continue;
    fi
    echo "Adding symlink of $scriptname to /usr/bin"
    chmod +x $scriptname
    rm /usr/bin/$scriptname &> /dev/null
    ln -s "$(pwd)/$scriptname" /usr/bin
done

cd "`dirname $BTCPAY_ENV_FILE`"
docker-compose -f $BTCPAY_DOCKER_COMPOSE up -d --remove-orphans
