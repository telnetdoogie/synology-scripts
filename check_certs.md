# Check Certs

[check_certs.sh](./check_certs.sh)

This script can be used to find certificate locations on synology NAS that differ from the provided / input certificate:
```
sudo check_certs.sh /path/to/certificate_to_compare.pem
```
It needs to be run as root (`sudo`) in order to access the synology's certificate folders and compare cert files.
Pass in a full path to a `cert.pem` file and it will walk the Synology certificates folder to check for certificates that
do not match the certificate passed in.

### Downloading

* ssh into the synology as a user with `sudo` rights
* download the script:
```
sudo wget -O check_certs.sh https://raw.githubusercontent.com/telnetdoogie/synology-scripts/main/check_certs.sh
```
* Make it executable:
```
sudo chmod +x check_certs.sh
```

### Usage

```
sudo ./check_certs.sh /volume1/docker/certbot/etc_letsencrypt/live/my-domain.com/cert.pem
```
**Typical Output:**

```
The following folders have certs that do not match the current version:

  - /usr/local/etc/certificate/WebStation/7e8b547e-bd85-4d0e-8cb5-74d09c38e9c3
    - Service    : 7e8b547e-bd85-4d0e-8cb5-74d09c38e9c3
    - Subscriber : WebStation

```
This script does not make any changes to any files. The `Service` and `Subscriber` fields are read from the `info` file in the certificate's location (if present) and might give clues to the certificates "owner" application or service.
