#!/bin/bash

. ./scripts/common

rm -rf ${ROOT_DIR}/certs

mkdir -p ${ROOT_DIR}/certs
mkdir -p ${ROOT_DIR}/certs/platform
mkdir -p ${ROOT_DIR}/certs/guest
mkdir -p ${ROOT_DIR}/certs/guest/launch
mkdir -p ${ROOT_DIR}/certs/guest/launch/sev
mkdir -p ${ROOT_DIR}/certs/guest/launch/sev-es

# platform certs
pushd ${ROOT_DIR}/certs/platform

openssl ecparam -genkey -name secp384r1 -noout -out ec384-key-pair.pem
openssl ec -in ec384-key-pair.pem -pubout -out ec384pub.pem

sevtool --generate_cek_ask
sevtool --pek_csr
sevtool --sign_pek_csr pek_csr.cert ec384-key-pair.pem
sevtool --pek_cert_import pek_csr.signed.cert oca.cert
sevtool --pdh_cert_export
sevtool --get_ask_ark
sevtool --export_cert_chain

cp pdh.cert ../guest/

popd

pushd ${ROOT_DIR}/certs/guest

wget https://download.amd.com/developer/eula/sev/ask_ark_milan.cert
head -c 1600 ask_ark_milan.cert > ask.cert
dd < /dev/zero bs=1600 count=1 > ark.cert
dd conv=notrunc if=ask_ark_milan.cert of=ark.cert skip=1600 iflag=skip_bytes

sevtool --generate_launch_blob 1
mv launch_blob.bin ${ROOT_DIR}/certs/guest/launch/sev
mv godh.cert ${ROOT_DIR}/certs/guest/launch/sev
mv tmp_tk.bin ${ROOT_DIR}/certs/guest/launch/sev

sevtool --generate_launch_blob 5
mv launch_blob.bin ${ROOT_DIR}/certs/guest/launch/sev-es
mv godh.cert ${ROOT_DIR}/certs/guest/launch/sev-es
mv tmp_tk.bin ${ROOT_DIR}/certs/guest/launch/sev-es

popd



