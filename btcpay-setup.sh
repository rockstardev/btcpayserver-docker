#!/bin/bash

if [ "$0" = "$BASH_SOURCE" ]; then
    echo "This script must be sourced \". btcpay-setup.sh\"" 
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root after running \"sudo su -\"" 
   return
fi

if [[ ! -d "Production-NoReverseProxy" ]]; then
   echo "You must run this script from inside the btcpayserver-docker folder" 
   return
fi

if ! git -C . rev-parse; then
    echo "You must run this script inside the git repository of btcpayserver-docker"
    return
fi

function display_help () {
cat <<-END
Usage:
------

Install BTCPay on this server
This script must be run as root

    -i : Run install

This script will:

* Install Docker
* Install Docker-Compose
* Setup BTCPay settings
* Make sure it starts at reboot via upstart or systemd
* Add BTCPay utilities in /usr/bin
* Start BTCPay

You can run again this script if you desire to change your configuration.
Except BTC and LTC, other crypto currencies are maintained by their own community. Run at your own risk.

Make sure you own a domain with DNS record pointing to your website and that port 80 is accessible before running this script.
This will be used to properly setup HTTPS via let's encrypt.

Environment variables:
    BTCPAY_HOST: The hostname of your website (eg. btcpay.example.com)
    LETSENCRYPT_EMAIL: A mail will be sent to this address if certificate expires and fail to renew automatically (eg. me@example.com, Default:me@example.com)
    NBITCOIN_NETWORK: The type of network to use (eg. mainnet, testnet or regtest. Default: mainnet)
    LIGHTNING_ALIAS: An alias for your lightning network node if used
    BTCPAYGEN_CRYPTO1: First supported crypto currency (eg. btc, ltc, none. Default: btc)
    BTCPAYGEN_CRYPTO2: Second supported crypto currency (eg. btc, ltc, none. Default: empty)
    BTCPAYGEN_CRYPTON: N th supported crypto currency where N is maximum at maximum 9. (eg. btc, ltc. Default: none)
    BTCPAYGEN_REVERSEPROXY: Whether to use or not a reverse proxy. NGinx setup HTTPS for you. (eg. nginx, none. Default: nginx)
    BTCPAYGEN_LIGHTNING: Lightning network implementation to use (eg. clightning, none)
    ACME_CA_URI: The API endpoint to ask for HTTPS certificate (default: https://acme-v01.api.letsencrypt.org/directory)

END
}

if [ "$1" != "-i" ]; then
    display_help
    return
fi

: "${LETSENCRYPT_EMAIL:=me@example.com}"
: "${NBITCOIN_NETWORK:=mainnet}"
: "${BTCPAYGEN_CRYPTO1:=btc}"
: "${BTCPAYGEN_REVERSEPROXY:=nginx}"
: "${BTCPAYGEN_LIGHTNING:=none}"
: "${ACME_CA_URI:=https://acme-v01.api.letsencrypt.org/directory}"

ORIGINAL_DIRECTORY=$(pwd)
BTCPAY_BASE_DIRECTORY="$(dirname $(pwd))"
BTCPAY_DOCKER_COMPOSE="$(pwd)/Generated/docker-compose.generated.yml"
BTCPAY_ENV_FILE="$BTCPAY_BASE_DIRECTORY/.env"

echo "
-------SETUP-----------
Parameters passed:
BTCPAY_HOST:$BTCPAY_HOST
LETSENCRYPT_EMAIL:$LETSENCRYPT_EMAIL
NBITCOIN_NETWORK:$NBITCOIN_NETWORK
LIGHTNING_ALIAS:$LIGHTNING_ALIAS
BTCPAYGEN_CRYPTO1:$BTCPAYGEN_CRYPTO1
BTCPAYGEN_CRYPTO2:$BTCPAYGEN_CRYPTO2
BTCPAYGEN_CRYPTO3:$BTCPAYGEN_CRYPTO3
BTCPAYGEN_CRYPTO4:$BTCPAYGEN_CRYPTO4
BTCPAYGEN_CRYPTO5:$BTCPAYGEN_CRYPTO5
BTCPAYGEN_CRYPTO6:$BTCPAYGEN_CRYPTO6
BTCPAYGEN_CRYPTO7:$BTCPAYGEN_CRYPTO7
BTCPAYGEN_CRYPTO8:$BTCPAYGEN_CRYPTO8
BTCPAYGEN_CRYPTO9:$BTCPAYGEN_CRYPTO9
BTCPAYGEN_REVERSEPROXY:$BTCPAYGEN_REVERSEPROXY
BTCPAYGEN_LIGHTNING:$BTCPAYGEN_LIGHTNING
ACME_CA_URI:$ACME_CA_URI
----------------------
Additional exported variables:
BTCPAY_DOCKER_COMPOSE=$BTCPAY_DOCKER_COMPOSE
BTCPAY_BASE_DIRECTORY=$BTCPAY_BASE_DIRECTORY
BTCPAY_ENV_FILE=$BTCPAY_ENV_FILE
----------------------
"

if [ -z "$BTCPAY_HOST" ]; then
    echo "BTCPAY_HOST should not be empty"
    return
fi

if [ -z "$BTCPAYGEN_CRYPTO1" ]; then
    echo "BTCPAYGEN_CRYPTO1 should not be empty"
    return
fi

if [ "$NBITCOIN_NETWORK" != "mainnet" ] && [ "$NBITCOIN_NETWORK" != "testnet" ] && [ "$NBITCOIN_NETWORK" != "regtest" ]; then
    echo "NBITCOIN_NETWORK should be equal to mainnet, testnet or regtest"
fi

export BTCPAY_DOCKER_COMPOSE
export BTCPAY_BASE_DIRECTORY
export BTCPAY_ENV_FILE

# Put the variables in /etc/profile.d when a user log interactively
touch "/etc/profile.d/btcpay-env.sh"
echo "
export BTCPAYGEN_CRYPTO1=\"$BTCPAYGEN_CRYPTO1\"
export BTCPAYGEN_CRYPTO2=\"$BTCPAYGEN_CRYPTO2\"
export BTCPAYGEN_CRYPTO3=\"$BTCPAYGEN_CRYPTO3\"
export BTCPAYGEN_CRYPTO4=\"$BTCPAYGEN_CRYPTO4\"
export BTCPAYGEN_CRYPTO5=\"$BTCPAYGEN_CRYPTO5\"
export BTCPAYGEN_CRYPTO6=\"$BTCPAYGEN_CRYPTO6\"
export BTCPAYGEN_CRYPTO7=\"$BTCPAYGEN_CRYPTO7\"
export BTCPAYGEN_CRYPTO8=\"$BTCPAYGEN_CRYPTO8\"
export BTCPAYGEN_CRYPTO9=\"$BTCPAYGEN_CRYPTO9\"
export BTCPAYGEN_LIGHTNING=\"$BTCPAYGEN_LIGHTNING\"
export BTCPAYGEN_REVERSEPROXY=\"$BTCPAYGEN_REVERSEPROXY\"
export BTCPAY_DOCKER_COMPOSE=\"$BTCPAY_DOCKER_COMPOSE\"
export BTCPAY_BASE_DIRECTORY=\"$BTCPAY_BASE_DIRECTORY\"
export BTCPAY_ENV_FILE=\"$BTCPAY_ENV_FILE\"
if cat \$BTCPAY_ENV_FILE 2> /dev/null; then
export BTCPAY_HOST=\"\$(cat \$BTCPAY_ENV_FILE | sed -n 's/^BTCPAY_HOST=\(.*\)$/\1/p')\"
export LETSENCRYPT_EMAIL=\"\$(cat \$BTCPAY_ENV_FILE | sed -n 's/^LETSENCRYPT_EMAIL=\(.*\)$/\1/p')\"
export NBITCOIN_NETWORK=\"\$(cat \$BTCPAY_ENV_FILE | sed -n 's/^NBITCOIN_NETWORK=\(.*\)$/\1/p')\"
export LIGHTNING_ALIAS=\"\$(cat \$BTCPAY_ENV_FILE | sed -n 's/^LIGHTNING_ALIAS=\(.*\)$/\1/p')\"
export ACME_CA_URI=\"\$(cat \$BTCPAY_ENV_FILE | sed -n 's/^ACME_CA_URI=\(.*\)$/\1/p')\"
fi
" > /etc/profile.d/btcpay-env.sh
chmod +x /etc/profile.d/btcpay-env.sh
echo -e "BTCPay Server environment variables successfully saved in /etc/profile.d/btcpay-env.sh\n"

if ! [ -x "$(command -v docker)" ] || ! [ -x "$(command -v docker-compose)" ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    if [ $(lsb_release -cs) == "bionic" ]; then
        # Bionic not in the repo yet, see https://linuxconfig.org/how-to-install-docker-on-ubuntu-18-04-bionic-beaver
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu artful stable"
    else
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    fi
    apt-get update 2>error
    apt-get install -y \
        curl \
        apt-transport-https \
        ca-certificates \
        software-properties-common \
        2>error
fi

if ! [ -x "$(command -v docker)" ]; then
    if apt-get install -y docker-ce ; then
        echo "Docker installed"
    else
        echo "Failed to install docker"
        return
    fi
else
    echo -e "docker is already installed\n"
fi

# Install docker-compose
if ! [ -x "$(command -v docker-compose)" ]; then
    curl -L https://github.com/docker/compose/releases/download/1.17.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    echo -e "docker-compose is already installed\n"
fi

# Set .env file
touch $BTCPAY_ENV_FILE
echo "
BTCPAY_HOST=$BTCPAY_HOST
ACME_CA_URI=$ACME_CA_URI
NBITCOIN_NETWORK=$NBITCOIN_NETWORK
LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL
LIGHTNING_ALIAS=$LIGHTNING_ALIAS" > $BTCPAY_ENV_FILE
echo -e "BTCPay Server docker-compose parameters saved in $BTCPAY_ENV_FILE\n"

# Generate the docker compose in BTCPAY_DOCKER_COMPOSE
. ./build.sh

# Schedule for reboot
if [ -d "/etc/systemd/system" ]; then # Use systemd
if [ -e "/etc/init/start_containers.conf" ]; then
    echo -e "Uninstalling upstart script /etc/init/start_containers.conf"
    rm "/etc/init/start_containers.conf"
    initctl reload-configuration
fi
echo "Adding btcpayserver.service to systemd"
echo "
[Unit]
Description=BTCPayServer service
After=docker.service network-online.target
Requires=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes

ExecStart=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd \"\$(dirname \$BTCPAY_ENV_FILE)\" && docker-compose -f \"\$BTCPAY_DOCKER_COMPOSE\" up -d'
ExecStop=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd \"\$(dirname \$BTCPAY_ENV_FILE)\" && docker-compose -f \"\$BTCPAY_DOCKER_COMPOSE\" stop'
ExecReload=/bin/bash -c '. /etc/profile.d/btcpay-env.sh && cd \"\$(dirname \$BTCPAY_ENV_FILE)\" && docker-compose -f \"\$BTCPAY_DOCKER_COMPOSE\" restart'

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/btcpayserver.service

echo -e "BTCPay Server systemd configured in /etc/systemd/system/btcpayserver.service\n"
systemctl daemon-reload
systemctl enable btcpayserver
systemctl start btcpayserver
echo "BTCPay Server started"
else # Use upstart
echo "Using upstart"
echo "
# File is saved under /etc/init/start_containers.conf
# After file is modified, update config with : $ initctl reload-configuration

description     \"Start containers (see http://askubuntu.com/a/22105 and http://askubuntu.com/questions/612928/how-to-run-docker-compose-at-bootup)\"

start on filesystem and started docker
stop on runlevel [!2345]

# if you want it to automatically restart if it crashes, leave the next line in
# respawn # might cause over charge

script
    . /etc/profile.d/btcpay-env.sh
    cd \"`dirname \$BTCPAY_ENV_FILE`\"
    docker-compose -f \"\$BTCPAY_DOCKER_COMPOSE\" up -d
end script" > /etc/init/start_containers.conf
    echo -e "BTCPay Server upstart configured in /etc/init/start_containers.conf\n"
    initctl reload-configuration
    cd "$(dirname $BTCPAY_ENV_FILE)"
    docker-compose -f "$BTCPAY_DOCKER_COMPOSE" up -d 
    echo "BTCPay Server started"
fi


cd $ORIGINAL_DIRECTORY

for scriptname in *.sh; do
    echo "Adding symlink of $scriptname to /usr/bin"
    chmod +x $scriptname
    if [ -e /usr/bin/$scriptname ]; then
        rm /usr/bin/$scriptname
    fi
    ln -s $scriptname /usr/bin
done

