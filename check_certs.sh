#!/bin/bash

readonly CERT_PATH=/usr/syno/etc/certificate
readonly PKGS_PATH=/usr/local/etc/certificate
readonly ARCHIVE_PATH=${CERT_PATH}/_archive
readonly INFO_FILE=${ARCHIVE_PATH}/INFO
readonly CONFIG_FILE="cert_config.json" 
readonly CERT_FILE="cert.pem"
declare -A cert_map # a map of CertID:CN that already exist
declare -a check_cns # CNs / Certs we will check or update
declare -A config_map # map of config entries to paths
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' 
UPDATE_MISMATCHES=false

# Give example usage
usage() {
    echo
    echo "Usage: sudo $0 "
    echo
    exit 1
}

# Terminate with error message
terminate() {
    echo
    echo "$1"
    echo
    exit "${2:-1}"
}

# Check whether a specific CN is in the map of cert:CNs
cn_exists_in_array() {
    local cn_to_find="$1"
    shift
    local array=("$@")
    for this_cn in "${array[@]}"; do
        if [[ "$this_cn" == "$cn_to_find" ]]; then
            return 0  # CN found in array
        fi
    done
    return 1  # CN not found in array
}


# Extract CN from a given certificate file
get_cert_cn() {
    local cert_file="$1"
    if [[ -f "$cert_file" ]]; then
        openssl x509 -in "$cert_file" -noout -subject | awk '{print $NF}'
    else
        echo ""
    fi
}

# Generate an empty config file based on existing certs in use
generate_config_file() {
    echo "Configuration file does not exist."
	echo " - Generating new configuration file: $CONFIG_FILE"
    
    # Create an array of objects with jq
    jq -n --argjson certs "$( 
        for certCode in "${!cert_map[@]}"; do
            cn="${cert_map[$certCode]}"
            jq -n --arg cn "$cn" --arg cert_path "" '{cn: $cn, cert_path: $cert_path}'
        done | jq -s .
    )" '{config: $certs}' > "$CONFIG_FILE"
    
    echo "Configuration file created successfully."
	echo
	echo " Edit the file $CONFIG_FILE and for those certs you want to check / update,"
	echo " add the path to your new certificates in \"cert_path\". Leaving this blank"
	echo " will exclude it from checks and updates."
	echo
}

# Function to read an existing configuration file
read_config_file() {
    echo "Reading configuration file: $CONFIG_FILE..."
	echo    
    # Check if the config file is valid JSON
    if ! jq empty "$CONFIG_FILE" > /dev/null 2>&1; then
        terminate "Configuration file $CONFIG_FILE is not valid JSON. Please check the syntax."
    fi

    # Read the CNs and cert paths from the config file into an associative array
    while IFS= read -r line; do
        cn=$(echo "$line" | jq -r '.cn')
        cert_path=$(echo "$line" | jq -r '.cert_path // ""')
        config_map["$cn"]="$cert_path"
    done < <(jq -c '.config[]' "$CONFIG_FILE")

    # Validate that each CN in cert_map has an entry in config_map
    for certCode in "${!cert_map[@]}"; do
        cn="${cert_map[$certCode]}"
        
        if [[ -v config_map["$cn"] ]]; then  # Check if CN exists in config_map
            if [[ -n "${config_map[$cn]}" ]]; then
                echo " - CN: $cn has a cert_path set."
				echo "    ${config_map[$cn]}"
				# read the cn from the cert.pem in cert_path
				cert_file="${config_map[$cn]}/cert.pem"
                cert_cn=$(get_cert_cn "$cert_file")
				if [[ "$cert_cn" == "$cn" ]]; then
                    echo "    - CN in cert.pem matches config CN. This CN will be checked."
                    check_cns+=("$cn")
                else
                    echo "    - Will not check $cn. CN in cert_path does not match ($cert_cn)."
                fi
            else
                echo " - CN: $cn will not be checked or updated (config file cert_path blank)"
            fi
        else
            echo " - CN: $cn will not be checked or updated (no entry in config file)"
        fi
    done

    # Check for entries in the config file with no corresponding CN in cert_map
    for config_cn in "${!config_map[@]}"; do
        if ! cn_exists_in_array "$config_cn" "${cert_map[@]}"; then
            echo " - CN: $config_cn has entry in config but CN not found in certs."
        fi
    done
	echo
    echo "CNs to check/update: ${check_cns[@]}"
    echo 
}


# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   usage
fi


# build entries in the cert_map array for certificate ID and cert name (CN) from existing certs
echo "Checking for Installed Certificates..."
echo

while IFS= read -r certCode; do
    cert_path="$ARCHIVE_PATH/$certCode/cert.pem"
    
    # Extract the CN (Common Name) from the certificate file
    if [[ -f "$cert_path" ]]; then
        cn=$(get_cert_cn "$cert_path")
        if [[ -n "$cn" ]]; then
            echo "  cert ID: $certCode  has CN: $cn"
            cert_map["$certCode"]="$cn"
        else
            terminate "Warning: CN not found in $cert_path"
        fi
    else
        terminate "Warning: Certificate file $cert_path not found"
    fi
done < <(jq -r 'keys[]' "$INFO_FILE")

echo
if [[ ${#cert_map[@]} -eq 0 ]]; then
    terminate "No configured certificates found"
fi

output_folder_check_md5(){
	local folder="$1"
	local check_md5="$2"
	local this_md5=$(md5sum "${folder}/${CERT_FILE}" | awk '{print $1}')
	if [[ "$check_md5" != "$this_md5" ]]; then
		# non-matching file
		echo -e " - ${RED}${folder}${NC}"
		return 1
	else
		# matching file
		echo -e " - ${GREEN}${folder}${NC}"
		return 0
	fi
}


# Function to iterate over the list of folders for a given certCode and CN
check_cert_folders() {
    local certCode="$1"
    local cn="$2"
    local count=0
	local mismatch_count=0
	local updated_md5=$(md5sum "${config_map["$cn"]}/${CERT_FILE}" | awk '{print $1}') 

    echo "Checking package cert folders for cert ID: $certCode, CN: $cn..."

    # Check folders under $PKGS_PATH using isPkg == true
    while IFS= read -r pkg_folder; do
        if [[ -d "$PKGS_PATH/$pkg_folder" ]]; then
            ((count++))
			output_folder_check_md5 "$PKGS_PATH/$pkg_folder" "$updated_md5"
			if [[ $? -eq 1 ]]; then
				((mismatch_count++))
			fi
		fi
    done < <(jq -r --arg certCode "$certCode" '.[$certCode] | .services[] | select(.isPkg == true) | "\(.subscriber)/\(.service)"' "$INFO_FILE")

    echo " ($count found, $mismatch_count mismatches)"
    echo

    # Reset count and check folders under $CERT_PATH using isPkg == false
    echo "Checking non-package cert folders for cert ID: $certCode, CN: $cn..."
    count=0
	mismatch_count=0


    while IFS= read -r cert_folder; do
        if [[ -d "$CERT_PATH/$cert_folder" ]]; then
            ((count++))
			output_folder_check_md5 "$CERT_PATH/$cert_folder" "$updated_md5"
			if [[ $? -eq 1 ]]; then
                ((mismatch_count++))
            fi
        fi
    done < <(jq -r --arg certCode "$certCode" '.[$certCode] | .services[] | select(.isPkg == false) | "\(.subscriber)/\(.service)"' "$INFO_FILE")

    echo " ($count found, $mismatch_count mismatches)"
    echo
}

# Check if the configuration file exists and act accordingly
if [[ ! -f "$CONFIG_FILE" ]]; then
    generate_config_file
fi    

# Read the config file, build check_cns array for certs to check.
read_config_file
if [[ ${#check_cns[@]} -eq 0 ]]; then
	terminate "Done... No Certificates to Check / Update."
fi



# For each CN to check, iterate folders and check certs
echo "Checking for mismatched certificates..."
echo
for certCode in "${!cert_map[@]}"; do
    cn="${cert_map[$certCode]}"

    if cn_exists_in_array "$cn" "${check_cns[@]}"; then
        check_cert_folders "$certCode" "$cn"
    fi
done




#CURRENT_VER=$(md5sum "$1" | awk '{print $1}')
#
#declare -a allcerts
#readarray -t syno_certs < <(find /usr/syno/etc/certificate/ -type f -name "cert.pem")
#readarray -t local_certs < <(find /usr/local/etc/certificate/ -type f -name "cert.pem")
#allcerts+=("${syno_certs[@]}")
#allcerts+=("${local_certs[@]}")
#declare -a certs_unmatching
#
#if [ ${#allcerts[@]} -eq 0 ]; then
#  echo "No certificates found."
#  exit 1
#fi
#
#for dir in "${allcerts[@]}"; do
#  THIS_VERSION=$(md5sum "$dir" | awk '{print $1}')
#  if [[ "$CURRENT_VER" != "$THIS_VERSION" ]]; then
#    certs_unmatching+=("$dir")
#  fi
#done
#
#if [ ${#certs_unmatching[@]} -eq 0 ]; then
#  echo "All certificates match the current version."
#else
#  echo "The following folders have certs that do not match the current version:"
#  for cert in "${certs_unmatching[@]}"; do
#    dirname=$(dirname ${cert})
#    echo
#    echo "  - $dirname"
#    if [ -f "$dirname/info" ]; then
#      echo "    - Service    : $(cat "$dirname/info" | jq -r ".service")"
#      echo "    - Subscriber : $(cat "$dirname/info" | jq -r ".subscriber")"
#    else
#      echo "    - (info file not found in $dirname)"
#    fi
#  done
#fi
#echo
