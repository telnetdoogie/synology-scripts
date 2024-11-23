#!/bin/bash

# Change this array to hold the containers you want to check
# No commas between items, each item in quotes.
# eg: CONTAINERS=("prowlarr" "transmission")

CONTAINERS=("prowlarr" "transmission")


# -----------------------------------------------------------
# No need to change anything below here
GRN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1;4m'

output(){
	MESSAGE=$1
	if [[ "$2" == "false" ]]; then
		COL=$RED
	else
		COL=$GRN
	fi
	echo -e "${COL}${MESSAGE}${NC}"
}

echo
echo "This hosts public IP:"
PUBLIC_IP=$(wget -q -O - http://api.ipify.org)
output "  - $PUBLIC_IP" "true"
echo

for CONTAINER in "${CONTAINERS[@]}"; do
echo -e "Checking ${BOLD}${CONTAINER}${NC}..."
echo " External IP: "
EXT_IP=$(docker exec "${CONTAINER}" /usr/bin/wget -q -O - http://api.ipify.org)
	if [[ "$EXT_IP" == "$PUBLIC_IP" ]]; then
		output "  - ${EXT_IP}" "false"
	else
		output "  - ${EXT_IP}" "true"
	fi
	echo " Check internet egress:"
	if docker exec "${CONTAINER}" ping -c 2 -W 1 8.8.8.8 > /dev/null 2>&1; then
		output "  - OK" "true"
	else
		output "  - FAIL" "false"
	fi
	echo " Check DNS resolution:"
	if docker exec "${CONTAINER}" ping -c 2 -W 1 google.com > /dev/null 2>&1; then
		output "  - OK" "true"
	else
		output "  - FAIL" "false"
	fi
	echo
done
echo
