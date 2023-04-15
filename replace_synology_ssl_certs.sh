#!/bin/bash


# modified version of https://gist.github.com/catchdave/69854624a21ac75194706ec20ca61327
# *** For DSM v7.2 ***

# 1. Initialization
# =================
[[ "$EUID" -ne 0 ]] && error_exit "Please run as root"  # Script only works as root
[[ "${DEBUG}" ]] && set -x

new_certs_origin_dir="/volume1/docker/certbot/etc_letsencrypt/live/{YOUR_DOMAIN_HERE}"
certs_src_dir="/usr/syno/etc/certificate/system/default"
target_cert_dirs=("/usr/syno/etc/certificate/system/FQDN")
file_to_check=cert.pem

services_to_restart=()
packages_to_restart=()

# Only continue if the source certs and destination certs differ
# ==============================================================
CURRENT_VER=`md5sum $new_certs_origin_dir/$file_to_check | awk '{ print $1 }'`
PREVIOUS_VER=`md5sum $certs_src_dir/$file_to_check | awk '{ print $1 }'`

echo "CURRENT_VER = $CURRENT_VER"
echo "PREVIOUS_VER = $PREVIOUS_VER"


if [ $CURRENT_VER == $PREVIOUS_VER ]; then
    echo "New certificates and current certificates do not differ, no action"
    exit 0
else
    echo "New certificates differ from system certificates.. replacing."
fi

# Add the default directory
default_dir_name=$(</usr/syno/etc/certificate/_archive/DEFAULT)
if [[ -n "$default_dir_name" ]]; then
    target_cert_dirs+=("/usr/syno/etc/certificate/_archive/${default_dir_name}")
	echo "Default cert directory found: '/usr/syno/etc/certificate/_archive/${default_dir_name}'"
else
	echo "No default directory found. Probably unusual? Check: 'cat /usr/syno/etc/certificate/_archive/DEFAULT'"
fi

# Add reverse proxy app directories
for proxy in /usr/syno/etc/certificate/ReverseProxy/*/; do
    echo "Found Reverse Proxy dir: ${proxy}"
    target_cert_dirs+=("${proxy}")
done



# 2. Move and chown certificates from /tmp to default directory
# =============================================================
cp $new_certs_origin_dir/{privkey,fullchain,cert}.pem "${certs_src_dir}/" || error_exit "Halting because of error moving files"
chown root:root "${certs_src_dir}/"{privkey,fullchain,cert}.pem || error_exit "Halting because of error chowning files"
chmod 600 "${certs_src_dir}/"{privkey,fullchain,cert}.pem || error_exit "Halting because of error chmoding files"
echo "Certs copied from $new_certs_origin_dir/ & chown, chmod complete."

# 3. Copy certificates to target directories if they exist
# ========================================================
for target_dir in "${target_cert_dirs[@]}"; do
	if [[ ! -d "$target_dir" ]]; then
		echo "Target cert directory '$target_dir' not found, skipping..."
		continue
	fi
	echo "Copying certificates to '$target_dir'"
	if ! cp "${certs_src_dir}/"{privkey,fullchain,cert}.pem "$target_dir/" && \
		chown root:root "$target_dir/"{privkey,fullchain,cert}.pem; then
		echo "Error copying or chowning certs to ${target_dir}"
	fi
done

# 4. Restart services & packages
# ==============================
echo "Rebooting all the things..."
for service in "${services_to_restart[@]}"; do
	/usr/syno/bin/synosystemctl restart "$service"
done
for package in "${packages_to_restart[@]}"; do  # Restart packages that are installed & turned on
	/usr/syno/bin/synopkg is_onoff "$package" 1>/dev/null && /usr/syno/bin/synopkg restart "$package"
done

# Faster ngnix restart (if certs don't appear to be refreshing, change to synosystemctl
if ! /usr/syno/bin/synow3tool --gen-all ; then
    echo "synow3tool --gen-all failed"
fi
if ! /usr/syno/bin/synow3tool --nginx=reload ; then
    echo "/usr/syno/bin/synow3tool --nginx=reload failed"
fi
if ! /usr/syno/bin/synow3tool --restart-dsm-service; then
    echo "/usr/syno/bin/synow3tool --restart-dsm-service failed"
fi

echo "Completed"
