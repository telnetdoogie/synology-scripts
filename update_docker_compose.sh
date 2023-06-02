#!/bin/bash

# inspired by https://gist.github.com/deviantony/2b5078fe1675a5fedabf1de3d1f2652a

COMPOSE_PATH=/var/packages/ContainerManager/target/usr/bin

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please run with sudo."
   exit 1
fi

if [[ ! -f "$COMPOSE_PATH/docker-compose" ]]; then
        echo "Error: docker-compose not found in system path."
        exit 1
fi

force=0
for arg in "$@"; do
    if [ "$arg" == "--force" ]; then
        force=1
    fi
done

CURRENT_COMPOSE_VER=$(docker-compose version | sed -n -e "s/^.*version\ //p")
LATEST_COMPOSE_VER=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')

echo "Current version of docker-compose: $CURRENT_COMPOSE_VER"
echo "Latest version of docker-compose: $LATEST_COMPOSE_VER"

if [[ "$CURRENT_COMPOSE_VER" = "$LATEST_COMPOSE_VER" ]]; then
        echo "Latest version of docker-compose already installed"
        if [ ! "$force" -eq 1 ]; then
                exit 1
        else
                echo "forcing update"
        fi
fi

echo "Installing latest version of docker-compose..."

   mv $COMPOSE_PATH/docker-compose $COMPOSE_PATH/docker-compose.$CURRENT_COMPOSE_VER && \
   curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o $COMPOSE_PATH/docker-compose && \
   chmod 755 $COMPOSE_PATH/docker-compose

NEW_COMPOSE_VER=$(docker-compose version | sed -n -e "s/^.*version\ //p")

echo "New version of docker-compose: $NEW_COMPOSE_VER"
