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

#### `removeAppleHiddenFiles.sh` 
- Deletes Apple 'hidden' files from the `/volume1/Media` folder (edit to add more folders)

#### `showports.sh` 
- Show LISTEN ports in use on synology and which containers use them, for easily coming up with new unique ports to use

#### `showComtainerLoggers.sh` 
- Iterate docker containers and show which logger is configured per container (prep for upgrading docker)

#### `test_containers_behind_vpn.sh` 
- For containers that are protected behind a VPN, validate their public IP is different than your host, and check for connectivity and DNS resolution.
  - edit the script to define containers to check, like `CONTAINERS=("prowlarr" "transmission")` 



