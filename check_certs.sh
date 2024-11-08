#!/bin/bash

readonly CERT_PATH=/usr/syno/etc/certificate
readonly PKGS_PATH=/usr/local/etc/certificate
readonly ARCHIVE_PATH=${CERT_PATH}/_archive
readonly INFO_FILE=${ARCHIVE_PATH}/INFO
readonly CONFIG_FILE="cert_config.json"  
declare -A cert_map


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

cn_exists_in_cert_map() {
    local cn_to_find="$1"
    for cert_cn in "${cert_map[@]}"; do
        if [[ "$cert_cn" == "$cn_to_find" ]]; then
            return 0  # CN found
        fi
    done
    return 1  # CN not found
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

# Function to validate an existing configuration file
validate_config_file() {
    echo "Checking configuration file: $CONFIG_FILE..."
    
    # Check if the config file is valid JSON
    if ! jq empty "$CONFIG_FILE" > /dev/null 2>&1; then
        terminate "Configuration file $CONFIG_FILE is not valid JSON. Please check the syntax."
    fi

    # Read the CNs and cert paths from the config file into an associative array
    declare -A config_map
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
                echo " - CN: $cn has a cert_path set: ${config_map[$cn]}"
            else
                echo " - CN: $cn will not be checked or updated (config file cert_path blank)"
            fi
        else
            echo " - CN: $cn will not be checked or updated (no entry in config file)"
        fi
    done

    # Check for entries in the config file with no corresponding CN in cert_map
    for config_cn in "${!config_map[@]}"; do
        if ! cn_exists_in_cert_map "$config_cn"; then
            echo " - CN: $config_cn has entry in config but CN not found in certs."
        fi
    done

    echo "Configuration validation completed."
}


# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   usage
fi

# Prepare and build array for certificate ID and cert name (CN)
echo "Checking for Installed Certificates..."
echo

while IFS= read -r certCode; do
    cert_path="$ARCHIVE_PATH/$certCode/cert.pem"
    
    # Extract the CN (Common Name) from the certificate file
    if [[ -f "$cert_path" ]]; then
        cn=$(openssl x509 -in "$cert_path" -noout -subject | awk '{print $NF}')
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

# For each installed certificate, iterate over the list of folders it's used in
for certCode in "${!cert_map[@]}"; do
    cn="${cert_map[$certCode]}"
    echo "Checking package cert folders for cert ID: $certCode, CN: $cn..."
    count=0

    # Check folders under $PKGS_PATH using isPkg == true
    while IFS= read -r pkg_folder; do
        if [[ -d "$PKGS_PATH/$pkg_folder" ]]; then
            ((count++))
            echo " - $PKGS_PATH/$pkg_folder"
        fi
    done < <(jq -r --arg certCode "$certCode" '.[$certCode] | .services[] | select(.isPkg == true) | "\(.subscriber)/\(.service)"' "$INFO_FILE")
    
    echo " ($count found)"
    echo

    # Reset count and check folders under $CERT_PATH using isPkg == false
    echo "Checking non-package cert folders for cert ID: $certCode, CN: $cn..."
    count=0

    while IFS= read -r cert_folder; do
        if [[ -d "$CERT_PATH/$cert_folder" ]]; then
            ((count++))
            echo " - $CERT_PATH/$cert_folder"
        fi
    done < <(jq -r --arg certCode "$certCode" '.[$certCode] | .services[] | select(.isPkg == false) | "\(.subscriber)/\(.service)"' "$INFO_FILE")
    
    echo " ($count found)"
    echo
done

# Check if the configuration file exists and act accordingly
if [[ ! -f "$CONFIG_FILE" ]]; then
    generate_config_file
fi    

validate_config_file

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
