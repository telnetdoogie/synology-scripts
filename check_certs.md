# Check Certs

[check_certs.sh](./check_certs.sh)

This script can be used to find certificate locations on synology NAS that differ from the provided / input certificate:
```
sudo check_certs.sh /path/to/certificate_to_compare.pem
```
It needs to be run as root (`sudo`) in order to access the synology's certificate folders and compare cert files.
Pass in a full path to a `cert.pem` file and it will walk the Synology certificates folder to check for certificates that
do not match the certificate passed in.

#### Downloading:

* ssh into the synology as a user with `sudo` rights
* download the script:
```
sudo wget -O update_docker_compose.sh https://raw.githubusercontent.com/telnetdoogie/synology-scripts/main/check_certs.sh
```
* Make it executable:
```
sudo chmod +x check_certs.sh
```

---

**Typical Usage:**

```
sudo ./check_certs.sh /volume1/docker/certbot/etc_letsencrypt/live/my-domain.com/cert.pem
```
**Typical Output:**

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
