# Replace Synology Certs

[replace_synology_ssl_certs.sh](./replace_synology_ssl_certs.sh)

_Based on / Inspired by [this gist](https://gist.github.com/catchdave/69854624a21ac75194706ec20ca61327) by @catchdave_

This script updates the SSL/TLS certificates for Synology services, specifically for DSM v7.2. It copies the new certificates to the appropriate directories, and then restarts the affected services and packages.

To use this script, you should modify the constants in the script to match your system's configuration, such as the location of the new certificates and any 'special' target folders to copy the certificates to. You can then run the script with root privileges, and optionally with the `--force` parameter to force the script to copy the certificates even if they have not changed.

### Downloading

* ssh into the synology as a user with `sudo` rights
* download the script:
```
sudo wget -O replace_synology_ssl_certs.sh https://raw.githubusercontent.com/telnetdoogie/synology-scripts/main/replace_synology_ssl_certs.sh
```
* Make it executable:
```
sudo chmod +x replace_synology_ssl_certs.sh
```

### Usage

This script can be scheduled to run on your Synology NAS with root priveleges. By default it will only make change if updated certificates are found in the `NEW_CERTIFICATE_LOCATION` folder. The output of this script, even if no changes are made, will include a list of certificates installed on the NAS that differ from the certificate in the `NEW_CERTIFICATE_LOCATION` folder, so you can add any locations you'd like to `TARGET_FOLDERS` if needed.

**Typical Output:**
```
Default cert directory found: /usr/syno/etc/certificate/_archive/auLTvE
New certificates and current certificates do not differ.

Warning: Some unmatched certs still exist, in the following locations:
======================================================================

  - /usr/local/etc/certificate/Bogus/7e8b547e-bd85-4d0e-8cb5-74d09c38e9c3
    - Service    : 7e8b547e-bd85-4d0e-8cb5-74d09c38e9c3
    - Subscriber : SomePackage

...check the script and add these folders to TARGET_FOLDERS for syncing
or alternatively add appropriate packages to PACKAGES_TO_RESTART for those services that auto-sync certs
(WebStation is an example of a package that will re-sync certs from the system default on restart)

 ...this script can then be run again with the '--force' parameter to retry
```

**Force Deployment:**
Running the script with `--force` will copy certs regardless of whether they differ from the source.

Typical output for a forced deployment looks similar to:
```
Default cert directory found: /usr/syno/etc/certificate/_archive/auLTvE
New certificates and current certificates do not differ.
--force parameter passed to script. Redeploying certificates...
Certs copied from /volume1/docker/certbot/etc_letsencrypt/live/hobbs-family.com/ to
         /usr/syno/etc/certificate/_archive/auLTvE/ & chown, chmod complete.
Copying certificates to '/usr/local/etc/certificate/ScsiTarget/pkg-scsi-plugin-server/'
Sync W3 certificate info successfully
Generate nginx tmp config successfully
restarting pkg-scsi-plugin-server
[pkg-scsi-plugin-server] restarted.
restarting WebStation
restart package [WebStation] successfully
restarting ScsiTarget
restart package [ScsiTarget] successfully
Start Nginx Server in Normal Mode ......

Warning: Some unmatched certs still exist, in the following locations:
======================================================================

  - /usr/local/etc/certificate/Bogus/7e8b547e-bd85-4d0e-8cb5-74d09c38e9c3
    - Service    : 7e8b547e-bd85-4d0e-8cb5-74d09c38e9c3
    - Subscriber : SomePackage

...check the script and add these folders to TARGET_FOLDERS for syncing
or alternatively add appropriate packages to PACKAGES_TO_RESTART for those services that auto-sync certs
(WebStation is an example of a package that will re-sync certs from the system default on restart)

 ...this script can then be run again with the '--force' parameter to retry
```

*Notice in the above outputs, I have created bogus certs in `/usr/local/etc/certificate/WebStation/7e8b547e-bd85-4d0e-8cb5-74d09c38e9c3` just to illustrate the output you might see if you have additional certificates that still differ once the script is complete. This output is useful in guiding you to add additional folders to the script in the `TARGET_FOLDERS` array or services / packages to `PACKAGES_TO_RESTART` or `SERVICES_TO_RESTART`*
