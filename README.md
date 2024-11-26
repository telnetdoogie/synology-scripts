# synology-scripts
A collection of scripts I use on my synology NAS

---

### [Check (and Update) Synology SSL Certs](./check_certs.md)

Check certificates deployed to synology NAS against (mulitple) renewed certificates

---

### [Copy SSL Certs](./copy_SSL_certs.md)

Copy new certificates and generated keystore to a specified location for use elsewhere on the network

---

### [Update Docker Compose Version](./update_docker_compose.md)

Update synology to the latest version of `docker-compose`

--- 

### Miscellaneous, Simple Scripts

#### `fix_nginx_auth.sh` 
- This script fixes nginx entries which have been escaped inappropriately by DSM Reverse Proxy changes (bug in 7.2+)
- Once you've added custom headers `Authorization` to your Reverse Proxy in the DSM UI, you can run this script after save.
- You will need to run the script after each edit of ANY Reverse Proxy since the DSM UI regenerates all settings (and breaks escaping) with any change to any RP entry.

Changes
```
  proxy_set_header  Authorization  \"Basic\ 9KcJl4yWkA+ZCmqkMoq9Zg==\"
```
to 
```
  proxy_set_header  Authorization  "Basic 9KcJl4yWkA+ZCmqkMoq9Zg=="
```

Edit the `USERNAME` and `PASSWORD` variables at the top of the script file with the username and password desired for use in your nginx config and it will unescape the string and automatically generate the correct entry for that username/password combination (base64 encoded)

This is very useful for fixing the `Radarr.Http.Authentication.BasicAuthenticationHandler|Basic was not authenticated. Failure message: Authorization header missing.` errors in Radarr when running behind Reverse Proxy, for example.

---

#### `removeAppleHiddenFiles.sh` 
- Deletes Apple 'hidden' files from the `/volume1/Media` folder (edit to add more folders)

---

#### `showports.sh` 
- Show LISTEN ports in use on synology and which containers use them, for easily coming up with new unique ports to use

---

#### `showComtainerLoggers.sh` 
- Iterate docker containers and show which logger is configured per container (prep for upgrading docker)

---

#### `test_containers_behind_vpn.sh` 
- For containers that are protected behind a VPN, validate their public IP is different than your host, and check for connectivity and DNS resolution.
  - edit the script to define containers to check, like `CONTAINERS=("prowlarr" "transmission")` 

---

#### `capture_docker_stats.sh` 
- Capture the CPU / Memory stats of running containers continually and store results as JSON for later analysis
- This is useful for watching the resource usage of containers (or a particular container) for troubleshooting.

run `capture_docker_stats.sh {containername} {-v}` - omitting `containername` defaults to all containers. `-v` outputs to screen as well as file.


