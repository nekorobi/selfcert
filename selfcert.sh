#!/bin/bash
# selfcert.sh
# MIT License © 2024 Nekorobi
version='1.1.0'
dir=./  bit=4096  day=3650  cn=CA   org=CA
unset debug cacert cakey cert key onlyca quiet fqdns san operand request; declare -a operand fqdns

help() {
  cat << END
Usage: ./selfcert.sh [Option]... Domain...

Generate CA and server self certificates.

Domain args:
  Specify FQDN (not ends with '.') or subdomain (ends with '.').
  e.g. example.com www. example.net mail.  (Equivalent to the following)
    => example.com www.example.com example.net mail.example.net
  Default: example.com, example.net, example.org,
           and the following subdomains, respectively:
             www. mail. imap. ldap. api. db.

Subject's CN(common name): the first domain
Subject alternative names: all the domains

Resulting File name:
  cacert.pem, cakey.pem, FirstDOMAIN/cert.pem, FirstDOMAIN/key.pem (e.g. example.com/key.pem)
  If the CA files exist in --directory, read them and make only the server ones.

Options:
  --bit Bits  (Default: 4096)
      RSA key size.
  --cn Name  (Default: CA)
      CN of the CA.
  --day Days  (Default: 3650)
      Number of days certificate is valid.
  -d, --directory Path  (Default: ./)
      Destination directory.
  --only-ca
      make only CA.
  --org Name  (Default: CA)
      O (organization name) of the CA.

  -h, --help     shows this help.
  -q, --quiet    be as quiet as possible.
  -V, --version  shows this version.

selfcert.sh v$version
MIT License © 2024 Nekorobi
END
}

error() { echo -e "\e[1;31mError:\e[m $1" 1>&2; [[ $2 ]] && exit $2 || exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
  --bit|--cn|--day|-d|--directory|--org) [[ $# = 1 || $2 =~ ^- ]] && error "$1: requires an argument";;&
  --bit)          [[ $2 =~ [0-9]+ ]] || error "$2: not an integer"; bit=$2; shift 2;;
  --cn)           [[ ${#2} -le 64 ]] || error "$2: too long"; cn=$2; shift 2;;
  --day)          [[ $2 =~ [0-9]+ ]] || error "$2: not an integer"; day=$2; shift 2;;
  -d|--directory) dir=$2; shift 2;;
  --only-ca)      onlyca=yes; shift 1;;
  --org)          [[ ${#2} -le 64 ]] || error "$2: too long"; org=$2; shift 2;;
  #
  -h|--help)      help; exit 0;;
  -q|--quiet)     quiet=on; shift 1;;
  -V|--version)   echo selfcert.sh $version; exit 0;;
  --debug)        debug=on; shift 1;;
  # ignore
  "") shift 1;;
  # invalid
  -*) error "$1: unknown option";;
  # Operand
  *)  [[ $1 =~ ^[-.a-z0-9]+$ ]] || error "$1: not a domain name" 2
      [[ ${#operand[@]} = 0 && $1 =~ \.$ ]] && error "$1: ends with '.' (The first domain should be FQDN)" 2
      operand[${#operand[@]}]=$1; shift 1;;
  esac
done

isFQDN() {
  [[ ${#1} -le 253 && $1 =~ ^[-a-z0-9]{1,63}(\.[-a-z0-9]{1,63})*$ &&
    ! $1 =~ ^[-.]|[-.]$|\.-|-\.|^..--|\...--|\.[0-9]+$|^[0-9]+$ ]] # exclude only numbers TLD
}

makeSAN() { # Subject alternative names
  [[ ${#operand[@]} = 0 ]] && operand=(example.com www. mail. imap. ldap. api. db.
    example.net www. mail. imap. ldap. api. db.  example.org www. mail. imap. ldap. api. db.)
  local i=1  parent=
  for e in "${operand[@]}"; do
    if [[ $e =~ \.$ ]]; then _fqdn=$e$parent; else parent=$e; _fqdn=$e; fi
    fqdns[${#fqdns[@]}]=$_fqdn
    isFQDN "$_fqdn" || error "$_fqdn: not a domain name" 2
    san+="DNS.$i = $_fqdn
  " # new line
    i=$((++i))
  done
  [[ $debug ]] && echo -e "${fqdns[@]}" "\n$san"
}

checkDirectory() { # --directory
  dir=$(readlink -m -- "$dir"); local dirCert=$dir/${fqdns[0]}
  mkdir -p "$dirCert" && [[ -w $dir && -x $dir && -w $dirCert && -x $dirCert ]] ||
    error "--directory: permission denied" 3
  # PEM filename
  cakey=$dir/cakey.pem  cacert=$dir/cacert.pem
  key=$dirCert/key.pem  cert=$dirCert/cert.pem
  [[ -f $key ]] && error "--directory: server key exists: $key" 3
  [[ -f $cert ]] && error "--directory: server certificate exists: $cert" 3
  [[ -f $cacert && ! -f $cakey ]] && error "--directory: cacert.pem exists, but cakey.pem does not" 3
  [[ ! -f $cacert && -f $cakey ]] && error "--directory: cakey.pem exists, but cacert.pem does not" 3
}

makeCA() { # man config x509v3_config
  local config="[req]
distinguished_name = dn
prompt = no
[dn]
O = $org
CN = $cn
[x509v3_ext]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
"
  openssl req -x509 -newkey rsa:$bit -noenc -keyout $cakey -out $cacert \
    -days $day -utf8 -extensions x509v3_ext -config <(echo "$config")
}

makeReq() {
  local config="[req]
distinguished_name = dn
prompt = no
[dn]
CN = ${fqdns[0]}
"
  request=$(openssl req -newkey rsa:$bit -noenc -keyout $key -config <(echo "$config")) || return 1
  if [[ $debug ]]; then echo "$request" | openssl req -text -noout; fi
}

makeServer() {
  local config="[req]
prompt = no
[x509v3_ext]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
basicConstraints = critical, CA:FALSE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
subjectAltName = @san
[san]
$san
"
  echo "$request" | openssl x509 -req -CAkey $cakey -CA $cacert -out $cert \
  -days $day -extensions x509v3_ext -extfile <(echo "$config")
}

# check openssl v3
{ type openssl && openssl version -v | grep "^OpenSSL 3\."; } >/dev/null 2>&1 ||
  error "openssl v3 is required)" 99

makeSAN; checkDirectory
if [[ -f $cacert && -f $cakey ]]; then
  [[ ! $quiet ]] && echo "use the existing CA: cacert.pem, cakey.pem"
else
  { if [[ $quiet ]]; then makeCA 2>/dev/null; else makeCA; fi; } || error "CA: failed" 10
fi
if [[ ! $onlyca ]]; then
  { if [[ $quiet ]]; then makeReq 2>/dev/null; else makeReq; fi; } || error "certificate request: failed" 11
  { if [[ $quiet ]]; then makeServer 2>/dev/null; else makeServer; fi; } || error "server certificate: failed" 12
fi
[[ $quiet ]] && exit 0
ls -l $cakey $cacert
[[ $onlyca ]] && exit 0 || ls -l $key $cert

# error status: option 1, operand 2, version 99
# --directory 3, ca 10, server 11-12
