#!/bin/bash
set -e; cd ${0%/*} # here
tmp=$(mktemp -d -p .)
cd $tmp; script=../../selfcert.sh  readcert=../../readcert.sh

# error: domain
$script 2>/dev/null example. && exit 40 || [[ $? = 2 ]] || exit 40
$script 2>/dev/null xxx yyy .example && exit 40 || [[ $? = 2 ]] || exit 40
$script 2>/dev/null 12--5.com && exit 40 || [[ $? = 2 ]] || exit 40 # valid: 1--45.com, 123--6.com

# default
$script >/dev/null 2>&1 || exit 50
result=$(openssl x509 -subject -noout -in example.com.cert.pem)
line='subject=CN = example.com'
[[ $result = $line ]] || exit 50
# existing cert
$script --quiet 2>/dev/null && exit 51 || [[ $? = 3 ]] || exit 51
rm -f *.pem

# --only-ca
$script --quiet --only-ca --bit 512 || exit 60
result=$($readcert cacert.pem -subject)
line='subject=O = CA, CN = CA'
[[ $result = $line ]] || exit 60
# use existing CA
hash=$(md5sum cacert.pem)
$script --quiet --bit 1024 || exit 61
[[ $hash = $(md5sum cacert.pem) ]] || exit 61
rm -f *.pem

cd ..; script=../selfcert.sh  readcert=../readcert.sh

#
cert=$tmp/example.net.cert.pem  bit=2222  day=400  year=$((1 + $(date +%Y)))
domains='example.net www. example.org example.com www. mail.'
$script --quiet -d $tmp/ --org 'CA org' --cn 'my CA' --day $day --bit $bit $domains || exit 70
result=$($readcert $cert -subject -issuer -ext subjectAltName)
line='subject=CN = example.net
issuer=O = CA org, CN = my CA
X509v3 Subject Alternative Name: 
    DNS:example.net, DNS:www.example.net, DNS:example.org, DNS:example.com, DNS:www.example.com, DNS:mail.example.com'
[[ $result = $line ]] || exit 70
$readcert $cert | grep 'Public-Key' | grep "$bit bit" >/dev/null || exit 71
[[ $($readcert $cert -enddate) =~ $year\ GMT ]] || exit 72

rm -fr $tmp
echo success: test.sh
