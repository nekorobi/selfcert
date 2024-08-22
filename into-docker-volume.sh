#!/bin/bash
[[ $# = 1 || $# = 2 ]] || exit 1
[[ -d $1 ]] || exit 2
dir=$(readlink -m "$1") # fullpath
[[ $# = 1 ]] && name=$(basename "$dir") || name=$2

docker run --rm \
  --mount type=volume,src="$name",dst=/mnt/volume \
  --mount type=bind,src="$dir",dst=/mnt/dir \
  alpine sh -c "cp /mnt/dir/*.pem /mnt/volume"

docker volume ls --filter name="$name"
