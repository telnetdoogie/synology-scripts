#!/bin/bash

# inspired by https://gist.github.com/deviantony/2b5078fe1675a5fedabf1de3d1f2652a

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please run with sudo."
   exit 1
fi

#find docker-compose
COMPOSE_EXEC=$(which docker-compose)

if [[ -z "${COMPOSE_EXEC}"  ]]; then
    echo "Error: docker-compose not found in system path."
    exit 1
fi

#get path to docker-compose
COMPOSE_PATH=$(dirname $(readlink ${COMPOSE_EXEC}))

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
echo

if [[ "$CURRENT_COMPOSE_VER" = "$LATEST_COMPOSE_VER" ]]; then
    echo "Latest version of docker-compose already installed!"
    if [ ! "$force" -eq 1 ]; then
        echo " - Exiting."
        exit 1
    else
        echo " - forcing update"
    fi
fi

echo
echo "Installing latest version of docker-compose..."

   echo "Backing up current version of docker-compose..."
   echo "  creating backup << $COMPOSE_PATH/docker-compose.$CURRENT_COMPOSE_VER >>"
   mv $COMPOSE_PATH/docker-compose $COMPOSE_PATH/docker-compose.$CURRENT_COMPOSE_VER && \
   curl -s -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o $COMPOSE_PATH/docker-compose && \
   chmod 755 $COMPOSE_PATH/docker-compose
   echo "  new docker-compose created"

NEW_COMPOSE_VER=$(docker-compose version | sed -n -e "s/^.*version\ //p")

BLUE="\033[0;34m"
NC="\033[0m"
echo -e "New version of docker-compose returns: ${BLUE} ${NEW_COMPOSE_VER} ${NC}"
echo
echo "  to revert / replace with previous version, use the following command:"
echo -e "  ${BLUE}sudo mv ${COMPOSE_PATH}/docker-compose.${CURRENT_COMPOSE_VER} ${COMPOSE_PATH}/docker-compose${NC}"
echo
