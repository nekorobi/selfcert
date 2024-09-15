# selfcert

[![Test](https://github.com/nekorobi/selfcert/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/nekorobi/selfcert/actions)

- Generate CA and server self certificates

## selfcert.sh
- This Bash script depends on openssl version 3.
- `./selfcert.sh --help`

### readcert.sh
- Specify the certificate PEM file
### into-docker.sh
- Set to a Docker volume|config|secret
- `./into-docker.sh --help`

## Example
```bash
./selfcert.sh --bit 3072 --day 365 --cn 'my CA' \
  --directory ./pem  example.org www. api.  example.net mail.

# First argument: PEM
# From the second: LESS="+/Certificate Output Options" man openssl-x509
./readcert.sh ./pem/example.org/cert.pem -subject -issuer -ext subjectAltName
```
```text
subject=CN = example.org
issuer=O = CA, CN = my CA
X509v3 Subject Alternative Name: 
    DNS:example.org, DNS:www.example.org, DNS:api.example.org, DNS:example.net, DNS:mail.example.net
```

## MIT License
- © 2024 Nekorobi
