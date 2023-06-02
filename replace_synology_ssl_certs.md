# Replace Synology Certs

[replace_synology_ssl_certs.sh](./replace_synology_ssl_certs.sh)

This script updates the SSL/TLS certificates for Synology services, specifically for DSM v7.2. It copies the new certificates to the appropriate directories, and then restarts the affected services and packages.

To use this script, you should modify the constants in the script to match your system's configuration, such as the location of the new certificates and any 'special' target folders to copy the certificates to. You can then run the script with root privileges, and optionally with the `--force` parameter to force the script to copy the certificates even if they have not changed.

### Downloading

* ssh into the synology as a user with `sudo` rights
* download the script:
```
sudo wget -O update_docker_compose.sh https://raw.githubusercontent.com/telnetdoogie/synology-scripts/main/replace_synology_ssl_certs.sh
```
* Make it executable:
```
sudo chmod +x replace_synology_ssl_certs.sh
```

### Usage

This script can be scheduled to run on your Synology NAS with root priveleges. By default it will only make change if updated certificates are found in the `NEW_CERTIFICATE_LOCATION` folder. The output of this script, even if no changes are made, will include a list of certificates installed on the NAS that differ from the certificate in the `NEW_CERTIFICATE_LOCATION` folder, so you can add any locations you'd like to `TARGET_FOLDERS` if needed.

**Typical Output:**
```
Default cert directory found: /usr/syno/etc/certificate/_archive/xynzcj
New certificates and current certificates do not differ.

Warning: Some unmatched certs still exist, in the following locations:
======================================================================
  - /usr/syno/etc/certificate/temp/cert.pem
  - /usr/syno/etc/certificate/temp2/cert.pem

...check the script and add these folders to TARGET_FOLDERS for syncing
  this script can then be run again with the '--force' parameter to force push to new folders
```

**Force Deployment:**
Running the script with `--force` will copy certs regardless of whether they differ from the source.

Typical output for a forced deployment looks similar to:
```
Default cert directory found: /usr/syno/etc/certificate/_archive/xynzcj
New certificates and current certificates do not differ.
--force parameter passed to script. Redeploying certificates...
Certs copied from /volume1/docker/certbot/etc_letsencrypt/live/my-domain.com/ to
         /usr/syno/etc/certificate/_archive/xynzcj/ & chown, chmod complete.
Copying certificates to '/usr/syno/etc/certificate/smbftpd/ftpd'
Copying certificates to '/usr/syno/etc/certificate/kmip/kmip'
Sync W3 certificate info successfully
Generate nginx tmp config successfully
restarting kmip
Fail to restart [kmip].
restarting ftpd
[ftpd] restarted.
Start Nginx Server in Normal Mode ......

Warning: Some unmatched certs still exist, in the following locations:
======================================================================
  - /usr/syno/etc/certificate/temp/cert.pem
  - /usr/syno/etc/certificate/temp2/cert.pem

...check the script and add these folders to TARGET_FOLDERS for syncing
  this script can then be run again with the '--force' parameter to force push to new folders

Done
```
