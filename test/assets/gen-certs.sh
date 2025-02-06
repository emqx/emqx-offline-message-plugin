#!/bin/bash

set -xe
mkdir -p certs
cd certs

openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj '/CN=ca/O=EMQX/C=CN'
openssl genrsa -out mysql-server.key 2048
openssl req -new -key mysql-server.key -out mysql-server.csr -subj '/CN=mysql-server/O=EMQX/C=CN'
openssl x509 -req -in mysql-server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out mysql-server.crt -days 365
openssl genrsa -out mysql-client.key 2048
openssl req -new -key mysql-client.key -out mysql-client.csr -subj '/CN=mysql-client/O=EMQX/C=CN'
openssl x509 -req -in mysql-client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out mysql-client.crt -days 365
