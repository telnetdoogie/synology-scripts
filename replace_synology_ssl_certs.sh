#!/bin/bash
# modified version of https://gist.github.com/catchdave/69854624a21ac75194706ec20ca61327
# 		 from https://github.com/catchdave
#
# - Important:
#       Before this script can run reliably, you must first manually import your LE certificates into DSM.
#       	Private Key ---------------> privkey.pem
#       	Certificate ---------------> cert.pem
#		Intermediate Certificate --> fullchain.pem
#
#	It's possible to initially import certs WITHOUT adding an Intermediate Cert, and while this works in most cases,
#	it will cause OpenVPN on Synology to fail, as it requires the intermediate certs present in fullchain.pem
#	You can also add fullchain.pem as the "Certificate" file, which works, but it's important to upload the correct files 
#	as above, so that the synology certificate sync tool will write the correct contents into the "info" files and associate
#	the correct files with the "cert", "chain", and "key".
#
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
NEW_CERTIFICATE_LOCATION="/volume1/docker/certbot/etc_letsencrypt/live/{your-domain-name}"	# location of your updated / generated certs
SYSTEM_CERTIFICATES_ROOT="/usr/syno/etc/certificate/"						# location of the root certificates folder
CERTIFICATE_FILENAME=cert.pem									# certificate file for comparing old / new															

#TARGET_FOLDERS=("/usr/local/etc/certificate/ScsiTarget/pkg-scsi-plugin-server/"									
#                "/usr/syno/etc/certificate/kmip/kmip")						# any folders not otherwise covered by the script

TARGET_FOLDERS=()										# any folders not otherwise covered by the script
# SERVICES_TO_RESTART=("kmip" "ftpd")								# a list of the synology services needing to be restarted
SERVICES_TO_RESTART=("pkg-scsi-plugin-server")
PACKAGES_TO_RESTART=("VPNCenter" "WebStation" "ScsiTarget")					# a list of the synology packages needing to be restarted (DSM 7.1 +)

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
    readarray -t syno_certs < <(find /usr/syno/etc/certificate/ -type f -name "cert.pem")
    readarray -t local_certs < <(find /usr/local/etc/certificate/ -type f -name "cert.pem")
    allcerts+=("${syno_certs[@]}")
    allcerts+=("${local_certs[@]}")
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
        for cert in "${certs_unmatching[@]}"; do
            dirname=$(dirname ${cert})
            echo
            echo "  - $dirname"
            if [ -f "$dirname/info" ]; then
                echo "    - Service    : $(cat "$dirname/info" | jq -r ".service")"
                echo "    - Subscriber : $(cat "$dirname/info" | jq -r ".subscriber")"
            else
                echo "    - (info file not found in $dirname)"
            fi
        done
        echo
        echo "...check the script and add these folders to TARGET_FOLDERS for syncing"
        echo "or alternatively add appropriate packages to PACKAGES_TO_RESTART or SERVICES_TO_RESTART for those "
        echo "services that auto-sync certs"
        echo "- WebStation is an example of a package that will re-sync certs from the system default on restart"
        echo
        echo " this script can then be run again with the '--force' parameter to retry"
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
cp $NEW_CERTIFICATE_LOCATION/{cert,chain,fullchain,privkey}.pem "${DEFAULT_TARGET_FOLDER}/" || error_exit "Halting because of error moving files"
chown root:root "${DEFAULT_TARGET_FOLDER}/"{cert,chain,fullchain,privkey}.pem || error_exit "Halting because of error chowning files"
chmod 400 "${DEFAULT_TARGET_FOLDER}/"{cert,chain,fullchain,privkey}.pem || error_exit "Halting because of error chmoding files"
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
	if ! cp "${DEFAULT_TARGET_FOLDER}/"{cert,chain,fullchain,privkey}.pem "$target_dir/" && \
		chown root:root "$target_dir/"{cert,chain,fullchain,privkey}.pem &&\
		chmod 400 "$target_dir/"{cert,chain,fullchain,privkey}.pem; then
		echo "Error copying certs or with chmod, chown to ${target_dir}"
	fi
done

# 4. Sync certs and Restart services & packages
# ==============================================
if ! /usr/syno/bin/synow3tool --gen-all ; then
    echo "synow3tool --gen-all failed"
fi

# for DSM 6 packages
for service in "${SERVICES_TO_RESTART[@]}"; do
	echo "restarting ${service}"
    /usr/syno/bin/synosystemctl restart "$service"
done

# for DSM 7.1+ packages
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
