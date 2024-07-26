#!/bin/bash

# TODO for you: add ca.cert.pem to trust store and configure explicit trust
# Generate Root CA key and certificate
openssl req -x509 -newkey rsa:4096 \
    -keyout rootca.pem -out rootca.crt \
    -sha256 -days 365 -nodes \
    -subj "/CN=ROOT-CA-TEST"

for service_name in rekor fulcio tuf dex; do
    # Generate extentions file
    cat << EOF > $service_name.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $service_name.sigstore.local
EOF

    # Generate service key and certificate request
    openssl req -new -newkey rsa:4096 \
        -keyout $service_name.pem \
        -subj "/CN=$service_name.sigstore.local" \
        -out $service_name.req -nodes

    # Sign service certificate using root ca key
    openssl x509 -req -in $service_name.req \
        -days 365 -sha256 -CA rootca.crt -CAkey rootca.pem \
        -CAcreateserial -out $service_name.crt \
        -extfile $service_name.ext

    # Delete existing cluster service secret
    kubectl delete secret $service_name-tls \
        --ignore-not-found \
        --namespace=$service_name-system

    # Create service tls secret
    kubectl create secret tls $service_name-tls \
        --namespace=$service_name-system \
        --cert=$service_name.crt \
        --key=$service_name.pem
done

#########################################################################

#domain="dex.sigstore.local"

#openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
#    -out $domain.crt -keyout $domain.key \
#    -subj "/CN=$domain" \
#    -reqexts SAN \
#    -extensions SAN \
#    -config <(cat /etc/ssl/openssl.cnf \
#        <(printf "[SAN]\nsubjectAltName=DNS:$domain,DNS:*.$domain"))


        