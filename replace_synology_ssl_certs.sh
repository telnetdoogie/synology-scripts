#!/bin/bash
# modified version of https://gist.github.com/catchdave/69854624a21ac75194706ec20ca61327
# 		 from https://github.com/catchdave
# *** For DSM v7.2 ***

# 1. Initialization
# =================
[[ "$EUID" -ne 0 ]] && error_exit "Please run as root"  # Script only works as root
[[ "${DEBUG}" ]] && set -x

new_certs_origin="/volume1/docker/certbot/etc_letsencrypt/live/{yourdomainhere}"
certs_target="/usr/syno/etc/certificate/"

# Add the default directory
default_dir_name=$(<$certs_target/_archive/DEFAULT)
if [[ -n "$default_dir_name" ]]; then
	target_cert_dir="${certs_target}_archive/${default_dir_name}"
	echo "Default cert directory found: ${target_cert_dir}"
else
	echo "No default directory found. Probably unusual? Check: 'cat /usr/syno/etc/certificate/_archive/DEFAULT'"
	exit 1
fi

file_to_check=cert.pem

target_cert_dirs=("/usr/syno/etc/certificate/smbftpd/ftpd/"
                    "/usr/syno/etc/certificate/kmip/kmip")
services_to_restart=("kmip" "ftpd")
packages_to_restart=()

# Only continue if the source certs and destination certs differ
# ==============================================================
CURRENT_VER=`md5sum ${new_certs_origin}/${file_to_check} | awk '{ print $1 }'`
PREVIOUS_VER=`md5sum ${target_cert_dir}/${file_to_check} | awk '{ print $1 }'`

echo "CURRENT_VER = $CURRENT_VER"
echo "PREVIOUS_VER = $PREVIOUS_VER"


if [ $CURRENT_VER == $PREVIOUS_VER ]; then
	echo "New certificates and current certificates do not differ, no action"
	exit 0
else
	echo "New certificates differ from system certificates.. replacing."
fi

# 2. Move and chown certificates from origin to destination directory
# ===================================================================
cp $new_certs_origin/{privkey,fullchain,cert}.pem "${target_cert_dir}/" || error_exit "Halting because of error moving files"
chown root:root "${target_cert_dir}/"{privkey,fullchain,cert}.pem || error_exit "Halting because of error chowning files"
chmod 400 "${target_cert_dir}/"{privkey,fullchain,cert}.pem || error_exit "Halting because of error chmoding files"
echo "Certs copied from $new_certs_origin/ to " 
echo "         $target_cert_dir/ & chown, chmod complete."

# 3. Copy certificates to additional target directories if they exist
# ===================================================================
for target_dir in "${target_cert_dirs[@]}"; do
	if [[ ! -d "$target_dir" ]]; then
		echo "Target cert directory '$target_dir' not found, skipping..."
		continue
	fi
	echo "Copying certificates to '$target_dir'"
	if ! cp "${target_cert_dir}/"{privkey,fullchain,cert}.pem "$target_dir/" && \
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

for service in "${services_to_restart[@]}"; do
	echo "restarting ${service}"
    /usr/syno/bin/synosystemctl restart "$service"
done

for package in "${packages_to_restart[@]}"; do  # Restart packages that are installed & turned on
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

echo "Completed"
