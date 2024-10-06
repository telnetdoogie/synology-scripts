#!/bin/bash

USAGE="
    sudo $0 /path/to/cert.pem
"


if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Please run with sudo."
   exit 1
fi

if [[ $# -eq 0 || -z "$1" ]]; then
  echo "Please specify the location of a cert file to compare against.
  $USAGE "
  exit 1
fi

CURRENT_VER=$(md5sum "$1" | awk '{print $1}')

declare -a allcerts
readarray -t syno_certs < <(find /usr/syno/etc/certificate/ -type f -name "cert.pem")
readarray -t local_certs < <(find /usr/local/etc/certificate/ -type f -name "cert.pem")
allcerts+=("${syno_certs[@]}")
allcerts+=("${local_certs[@]}")
declare -a certs_unmatching

if [ ${#allcerts[@]} -eq 0 ]; then
  echo "No certificates found."
  exit 1
fi

for dir in "${allcerts[@]}"; do
  THIS_VERSION=$(md5sum "$dir" | awk '{print $1}')
  if [[ "$CURRENT_VER" != "$THIS_VERSION" ]]; then
    certs_unmatching+=("$dir")
  fi
done

if [ ${#certs_unmatching[@]} -eq 0 ]; then
  echo "All certificates match the current version."
else
  echo "The following certificates do not match the current version:"
  printf '%s\n' "${certs_unmatching[@]}" | sed 's/^/    - /'
fi
