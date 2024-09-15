#!/bin/bash
set -e; cd ${0%/*} # here
tmp=$(mktemp -d -p .); name=${tmp#*/}
echo -n test > $tmp/test
script=../into-docker.sh

# Volume
$script $tmp
result=$(docker volume ls --quiet --filter name=$name)
[[ $result = $name ]] || exit 20
$script --volume $tmp --name $name
result=$(docker volume ls --quiet --filter name=$name)
[[ $result = $name ]] || exit 21
result=$(docker run --rm -it --mount type=volume,src=$name,dst=/mnt  alpine:3 cat /mnt/$name/test)
[[ $result = test ]] || exit 22
docker volume rm $name >/dev/null
# ends with '/.'
$script --volume $tmp/.
result=$(docker run --rm -it --mount type=volume,src=$name,dst=/mnt  alpine:3 cat /mnt/test)
[[ $result = test ]] || exit 23
docker volume rm $name >/dev/null

# Config
$script --config $tmp/test --name $name
result=$(docker config ls --quiet --filter name=$name)
[[ $result ]] || exit 30
docker config rm $name >/dev/null

# Secret
$script --secret $tmp/test --name $name
result=$(docker secret ls --quiet --filter name=$name)
[[ $result ]] || exit 40
docker secret rm $name >/dev/null

rm -fr $tmp
echo success: test-into-docker.sh
