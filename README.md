# synology-scripts
A collection of scripts I use on my synology NAS

### Check Certs
[check_certs.sh](./check_certs.sh) 
This script can be used to find certificate locations that differ from the input certificate:
```
sudo check_certs.sh /path/to/certificate_to_compare.pem
```
It needs to be run as root (`sudo`) in order to access the synology's certificate folders and compare cert files.
Pass in a full path to a `cert.pem` file and it will walk the Synology certificates folder to check for certificates that 
do not match the certificate passed in.

**Typical Usage:** \
```
sudo ./check_certs.sh /volume1/docker/certbot/etc_letsencrypt/live/my-domain.com/cert.pem
```
**Typical Output:** \
```
The following certificates do not match the current version:
    - /usr/syno/etc/certificate/_archive/xynzcj/cert.pem
    - /usr/syno/etc/certificate/kmip/kmip/cert.pem
    - /usr/syno/etc/certificate/smbftpd/ftpd/cert.pem
    - /usr/syno/etc/certificate/temp/cert.pem
    - /usr/syno/etc/certificate/system/default/cert.pem
    - /usr/syno/etc/certificate/system/FQDN/cert.pem
    - /usr/syno/etc/certificate/ReverseProxy/4eb86f9e-880d-47e7-9a49-e473d4383dc3/cert.pem
    - /usr/syno/etc/certificate/ReverseProxy/209efc5f-5ff1-4f41-b34a-afa8d843814b/cert.pem
    - /usr/syno/etc/certificate/ReverseProxy/06e7ddea-0ce5-40c0-8464-0dfd444210fe/cert.pem
    - /usr/syno/etc/certificate/ReverseProxy/e6d25084-7f5c-426e-ae75-6ec22fe15d95/cert.pem
    - /usr/syno/etc/certificate/temp2/cert.pem
```
This script does not make any changes to any files.

### Copy Certs
[copy_SSL_certs.sh](./copy_SSL_certs.sh)
This script can be used to copy certificates, and generate a new `keystore` file specifically for use on the Unifi platform
(I use this to generate `keystore` file for a Unifi Dream Machine Pro)
It will only move files and generate a keystore if the certificates have changed between source and destination.
I schedule this script to run nightly. 
- If cert has not changed, the script will exit
- If a new cert is detected, it will copy files and generate keystore, and exit with code 1.
Exiting with code 1 on a 'successful push' allows "Send run details only when the script terminates abnormally" on the Synology Task Scheduler to send an email summarizing that changes were made.

Output when certificates are found and moved:
```
Certificates have been updated; Copying to new location
Importing keystore /var/services/homes/admin/ssl_certs/temp.p12 to /var/services/homes/admin/ssl_certs/keystore...
```
Things to change for your setup:

`NEW_CERT_PATH` - The location of your 'live' CERT files, perhaps from a `certbot` output \
`DESTINATION_PATH` - Destination you want your files to be copied to \
`SCP_USER` - The user that will be used to SCP into the location to pick up the files from any external boxes \


