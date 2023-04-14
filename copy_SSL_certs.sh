#!/bin/bash

# Copies Letsencrypt certs to staging for unifi devices
# additionally, generates "keystore" JKS for alternative cert storage on Ubiquiti UDM Pro
# ...this is specifically written for a Synology NAS with generated LetsEncrypt certs
# depends on the installation of Java in Synology package manager
# for DSM 7 and above, use RedNoah's Java Installer: https://github.com/rednoah/java-installer

SCP_USER={user for SCP}
FILE_TO_CHECK=cert.pem
OUTPUT_FILE=cert.pem
SYSTEM_CERT_PATH=/usr/syno/etc/certificate/system/default
DESTINATION_PATH=/var/services/homes/admin/ssl_certs
KEYTOOL_PATH=/var/packages/java-installer/target/bin

# default keystorepass for Unifi, change if generating for some other system
# KEYSTORE_PASS=aircontrolenterprise
KEYSTORE_PASS=aircontrolenterprise
# default alias for Unifi, change if generaing for some other system
# KEYSTORE_ALIAS=unifi
KEYSTORE_ALIAS=unifi

CURRENT_VER=`md5sum $SYSTEM_CERT_PATH/$FILE_TO_CHECK | awk '{ print $1 }'`
PREVIOUS_VER=`md5sum $DESTINATION_PATH/$OUTPUT_FILE | awk '{ print $1 }'`

if [ $CURRENT_VER == $PREVIOUS_VER ]; then
  echo "Certificates have not been updated, no action"
  exit 0
else
  echo "Certificates have been updated; Copying to new location"
  rm $DESTINATION_PATH/*
  cp $SYSTEM_CERT_PATH/RSA-cert.pem $DESTINATION_PATH/cert.pem
  cp $SYSTEM_CERT_PATH/RSA-privkey.pem $DESTINATION_PATH/privkey.pem
  cp $SYSTEM_CERT_PATH/RSA-fullchain.pem $DESTINATION_PATH/fullchain.pem


  openssl pkcs12 -export -in $DESTINATION_PATH/cert.pem -inkey $DESTINATION_PATH                                                                                                              /privkey.pem \
         -out $DESTINATION_PATH/temp.p12 -name $KEYSTORE_ALIAS -CAfile $DESTINAT                                                                                                              ION_PATH/fullchain.pem \
         -caname root -password pass:$KEYSTORE_PASS

  $KEYTOOL_PATH/keytool -importkeystore -deststorepass $KEYSTORE_PASS -destkeypa                                                                                                              ss $KEYSTORE_PASS \
         -destkeystore $DESTINATION_PATH/keystore -srckeystore $DESTINATION_PATH                                                                                                              /temp.p12 \
         -srcstoretype PKCS12 -srcstorepass $KEYSTORE_PASS -alias $KEYSTORE_ALIA                                                                                                              S -noprompt

  rm $DESTINATION_PATH/temp.p12
  chown $SCP_USER $DESTINATION_PATH/*
  chmod 700 $DESTINATION_PATH/*

fi

exit 1
