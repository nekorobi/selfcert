#!/bin/bash
# into-docker.sh
# MIT License © 2024 Nekorobi
version='1.0.3'
target=volume
unset debug name source

help() {
  cat << END
Usage: ./into-docker.sh [Option]... File|Directory

Set to a Docker Volume|Config|Secret.

Options:
  -v, --volume  (Default option)
      Put the directory into the Docker Volume.
      If the directory ends with '/.' (slash followed by dot),
      the contents of the directory are copied.
      e.g. ./into-docker.sh --volume /path/to/src/. --name my-volume
  -c, --config
      Write the file to the Docker Swarm Config.
  -s, --secret
      Write the file to the Docker Swarm Secret.
  -n, --name Name
      The name of the Docker resource.
      Default: Name of the specified file or directory.

  -h, --help     shows this help.
  -V, --version  shows this version.

into-docker.sh v$version
MIT License © 2024 Nekorobi
END
}

error() { echo -e "\e[1;31mError:\e[m $1" 1>&2; [[ $2 ]] && exit $2 || exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
  -n|--name)      [[ $# = 1 || $2 =~ ^- ]] && error "$1: requires an argument";;&
  -c|--config)    target=config; shift 1;;
  -s|--secret)    target=secret; shift 1;;
  -n|--name)      name=$2; shift 2;;
  -v|--volume)    target=volume; shift 1;;
  #
  --debug)        debug=on; shift 1;;
  -h|--help)      help; exit 0;;
  -V|--version)   echo into-docker.sh $version; exit 0;;
  # ignore
  "") shift 1;;
  # invalid
  -*) error "$1: unknown option";;
  # Operand
  *)  [[ $source ]] && error "$source, $1: specify a single file or directory" 2; source=$1; shift 1;;
  esac
done

if [[ $target = volume ]]; then
  [[ -d $source ]] || error "specify a directory" 2
else
  [[ -f $source || -p $source ]] || error "specify a file" 2 # ok: --config <(echo abc)
  docker info | egrep '^\s*Swarm: active$' >/dev/null || error 'Swarm inactive' 9
  docker info | egrep '^\s*Is Manager: true$' >/dev/null || error 'Not a Manager. Run in Manager node.' 9
fi
[[ -r $source ]] || error "$source: permission denied" 2
[[ $name ]] || name=$(basename "${source%/.}")
# Leave more detailed rules to Docker.
[[ $name =~ ^[a-zA-Z0-9] ]] || error "--name $name: the start character must be [a-zA-Z0-9]" 2
[[ $name =~ ^[a-zA-Z0-9_.-]+$ ]] || error "--name $name: only [a-zA-Z0-9_.-] are allowed" 2
[[ $debug ]] && { echo $target, "$source", $name; exit 0; }

if [[ $target = volume ]]; then
  docker volume create $name >/dev/null || error "docker volume create: failed" 10
  container=$(docker run --rm -d --mount type=volume,src=$name,dst=/mnt  alpine:3 sleep infinity)
  [[ $container ]] || error "docker run: failed" 11
  docker cp --quiet "$source" $container:/mnt; status=$?
  docker kill $container >/dev/null
  [[ $status = 0 ]] || error "docker cp: failed" 12
else
  cat "$source" | docker $target create $name - >/dev/null || error "docker $target create: failed" 20
fi
