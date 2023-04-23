#!/bin/bash
# modified version of https://gist.github.com/catchdave/69854624a21ac75194706ec20ca61327
# 		 from https://github.com/catchdave
# *** For DSM v7.2 **

# Check for --force and --debug parameters
force=0
for arg in "$@"; do
    if [ "$arg" == "--force" ]; then
        force=1
    fi
    if [ "$arg" == "--debug" ]; then
    	set -x    
    fi
done

# CONSTANTS
NEW_CERTIFICATE_LOCATION="/volume1/docker/certbot/etc_letsencrypt/live/{your_domain_name}"	# location of your updated / generated certs
SYSTEM_CERTIFICATES_ROOT="/usr/syno/etc/certificate/"						# location of the root certificates folder
CERTIFICATE_FILENAME=cert.pem									# certificate file for comparing old / new															
TARGET_FOLDERS=("/usr/syno/etc/certificate/smbftpd/ftpd"									
                    "/usr/syno/etc/certificate/kmip/kmip")					# any folders not otherwise covered by the script
SERVICES_TO_RESTART=("kmip" "ftpd")								# a list of the synology services needing to be restarted
PACKAGES_TO_RESTART=()										# a list of the synology packages needing to be restarted

# Functions
# ==========

# Function to call on errors
error_exit() {
    echo "[ERROR] : $1" >&2
    exit 1
}


# Function to check for unmatched certs
#  this function takes an MD5 to compare found certs against.
function find_unmatched_certs() {
    local updated_cert_md5=$1
    declare -a allcerts
    readarray -t allcerts < <(find ${SYSTEM_CERTIFICATES_ROOT} -type f -name "${CERTIFICATE_FILENAME}")
    declare -a certs_unmatching

    for cert in "${allcerts[@]}"; do
        THIS_VERSION=$(md5sum < ${cert} | awk '{print $1}')
        if [ $updated_cert_md5 != $THIS_VERSION ]; then
            certs_unmatching+=("${cert}")
        fi
    done

	if [ ! ${#certs_unmatching[@]} -eq 0 ]; then
        echo 
        echo "Warning: Some unmatched certs still exist, in the following locations:"
        echo "======================================================================"
        for location in "${certs_unmatching[@]}"; do
            echo "  - ${location}"
        done
        echo 
        echo "...check the script and add these folders to TARGET_FOLDERS for syncing"
		echo "  this script can then be run again with the '--force' parameter to force push to new folders"
		echo 
    fi
}

# Initialization
# ===============
if [[ "$EUID" -ne 0 ]]; then 
	error_exit "This script must be run as root. Try sudo $0"  # Script only works as root
fi

# Discover the default directory
DEFAULT_CERTIFICATE_FOLDER_NAME=$(<$SYSTEM_CERTIFICATES_ROOT/_archive/DEFAULT)
if [[ -n "$DEFAULT_CERTIFICATE_FOLDER_NAME" ]]; then
	DEFAULT_TARGET_FOLDER="${SYSTEM_CERTIFICATES_ROOT}_archive/${DEFAULT_CERTIFICATE_FOLDER_NAME}"
	echo "Default cert directory found: ${DEFAULT_TARGET_FOLDER}"
else
	error_exit "No default directory found. Probably unusual? Check: 'cat ${SYSTEM_CERTIFICATES_ROOT}_archive/DEFAULT'"
fi


# Only continue if the source certs and destination certs differ
# ==============================================================
UPDATED_CERT_MD5=`md5sum ${NEW_CERTIFICATE_LOCATION}/${CERTIFICATE_FILENAME} | awk '{ print $1 }'`
DEPLOYED_CERT_MD5=`md5sum ${DEFAULT_TARGET_FOLDER}/${CERTIFICATE_FILENAME} | awk '{ print $1 }'`

if [ $UPDATED_CERT_MD5 == $DEPLOYED_CERT_MD5 ]; then
	echo "New certificates and current certificates do not differ. "
	if [ ! "$force" -eq 1 ]; then	
		find_unmatched_certs $UPDATED_CERT_MD5
		exit 0
	else
		echo "--force parameter passed to script. Redeploying certificates..."
	fi
else
	echo "New certificates differ from system certificates.. replacing..."
fi

# 2. Move and chown certificates from origin to destination directory
# ===================================================================
cp $NEW_CERTIFICATE_LOCATION/{privkey,fullchain,cert}.pem "${DEFAULT_TARGET_FOLDER}/" || error_exit "Halting because of error moving files"
chown root:root "${DEFAULT_TARGET_FOLDER}/"{privkey,fullchain,cert}.pem || error_exit "Halting because of error chowning files"
chmod 400 "${DEFAULT_TARGET_FOLDER}/"{privkey,fullchain,cert}.pem || error_exit "Halting because of error chmoding files"
echo "Certs copied from $NEW_CERTIFICATE_LOCATION/ to " 
echo "         $DEFAULT_TARGET_FOLDER/ & chown, chmod complete."

# 3. Copy certificates to additional target directories if they exist
# ===================================================================
for target_dir in "${TARGET_FOLDERS[@]}"; do
	if [[ ! -d "$target_dir" ]]; then
		echo "Target cert directory '$target_dir' not found, skipping..."
		continue
	fi
	echo "Copying certificates to '$target_dir'"
	if ! cp "${DEFAULT_TARGET_FOLDER}/"{privkey,fullchain,cert}.pem "$target_dir/" && \
		chown root:root "$target_dir/"{privkey,fullchain,cert}.pem &&\
		chmod 400 "$target_dir/"{privkey,fullchain,cert}.pem; then
		echo "Error copying certs or with chmod, chown to ${target_dir}"
	fi
done

# 4. Sync certs and Restart services & packages
# ==============================================
if ! /usr/syno/bin/synow3tool --gen-all ; then
    echo "synow3tool --gen-all failed"
fi

for service in "${SERVICES_TO_RESTART[@]}"; do
	echo "restarting ${service}"
    /usr/syno/bin/synosystemctl restart "$service"
done

for package in "${PACKAGES_TO_RESTART[@]}"; do  # Restart packages that are installed & turned on
	/usr/syno/bin/synopkg is_onoff "$package" 1>/dev/null && \
	echo "restarting ${package}" && \
	/usr/syno/bin/synopkg restart "$package"
done

if ! /usr/syno/bin/synow3tool --nginx=reload ; then
    echo "/usr/syno/bin/synow3tool --nginx=reload failed"
fi
if ! /usr/syno/bin/synow3tool --restart-dsm-service; then
    echo "/usr/syno/bin/synow3tool --restart-dsm-service failed"
fi

# Always check for unmatched certs at successful conclusion of script
find_unmatched_certs $UPDATED_CERT_MD5

echo "Done"
