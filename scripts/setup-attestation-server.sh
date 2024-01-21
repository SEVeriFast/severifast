#!/bin/bash

. ./scripts/common

KEYS_DIR=/var/www/keys
CGI_BIN=/usr/lib/cgi-bin
CERTS_DIR=/var/www/certs

sudo mkdir -p ${KEYS_DIR}
sudo mkdir -p ${CGI_BIN}
sudo mkdir -p ${CERTS_DIR}

sudo chown www-data:www-data ${KEYS_DIR}
sudo chown www-data:www-data ${CGI_BIN}
sudo chown www-data:www-data ${CERTS_DIR}

sudo touch /var/www/cgi.log
sudo chown www-data:www-data /var/www/cgi.log

sudo cp ${ROOT_DIR}/attestation/http.conf /etc/nginx/sites-enabled/
sudo cp ${ROOT_DIR}/attestation/disk-key.sh ${CGI_BIN}
# we know attestation succeeded if /bin/signal runs because the path is the "key" given when attestation succeeds
echo "/bin/signal" | sudo tee /var/www/keys/000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 > /dev/null

# certs used to validate attestation report
sudo ${BIN_DIR}/snphost fetch ca pem /var/www/certs
sudo ${BIN_DIR}/snphost fetch vcek pem /var/www/certs

