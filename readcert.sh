#!/bin/bash
[[ -f $1 && -r $1 ]] || exit 1

if [[ $# = 1 ]]; then
  openssl x509 -text -noout -in "$1"
else
  openssl x509 -noout -in "$@"
fi
