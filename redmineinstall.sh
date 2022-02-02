#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT;

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
 cat <<EOF

Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-i] [-p]

Install all deps for Docker engine & install redmine & postgresql with docker

Available options:

-h, --help Print this help and exit
-v, --verbose Print script debug info
-p, --prepare Prepare system to instal redmine with docker
-i, --install Pull & run docker redmine & postgresql containers
EOF
 exit
}


cleanup() {
 trap - SIGINT SIGTERM ERR EXIT
 # script cleanup here
 rm -f install.yml
}

setup_colors() {
 if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
 NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' 
BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
 else
 NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
 fi
}

msg() {
 echo >&2 -e "${1-}"
}

die() {
 local msg=$1
 local code=${2-1} # default exit status 1
 msg "$msg"
 exit "$code"
}

setmsg() {
msg "${CYAN}Message!${NOFORMAT}"
}

prepare() {
  setup_colors

  echo -e "\nCleanup old installations"
  echo "RUN: sudo apt-get remove docker docker-engine docker.io containerd runc"
  sudo apt-get remove docker docker-engine docker.io containerd runc

  echo -e "\nUpdate apt"
  echo "RUN: sudo apt-get update"
  sudo apt-get update

  echo -e "\nInstall deps"
  echo "RUN: apt-get install ca-certificates curl gnupg lsb-release"
  sudo apt-get install ca-certificates curl gnupg lsb-release pwgen
  
  echo -e "\nAdd gpg key"
  echo "RUN: curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

  echo -e "\nAdd repository"
  echo 'RUN: echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  echo -e "\nInstall Docker"
  echo "RUN: apt-get update && apt-get -y install docker-ce docker-ce-cli containerd.io"
  sudo apt-get update
  sudo apt-get -y install docker-ce docker-ce-cli containerd.io

  exit
}

install() {
  local dbpass=`pwgen 15 1`
  echo -e "\nInstall PostgreSQL"
  echo 'RUN: docker run -d --restart always --name psql-redmine --log-opt tag="{{.Name}}" --log-driver syslog --hostname redminedb -e POSTGRES_PASSWORD=psqlpass postgres'
  docker run -d --restart always --name psql-redmine --log-opt tag="{{.Name}}" --log-driver syslog --hostname redminedb -e POSTGRES_PASSWORD=${dbpass} postgres

  echo -e "\nInstall REDMINE"
  echo 'RUN: docker run -d --restart always --name redmine-lab --log-opt tag="{{.Name}}" --log-driver syslog -p 8088:3000 --link psql-redmine -e REDMINE_SECRET_KEY_BASE=supersecret -e REDMINE_DB_POSTGRES=redminedb -e REDMINE_DB_DATABASE=postgres -e REDMINE_DB_USERNAME=postgres -e REDMINE_DB_PASSWORD=psqlpass redmine'
  docker run -d --restart always --name redmine-lab --log-opt tag="{{.Name}}" --log-driver syslog -p 8088:3000 --link psql-redmine -e REDMINE_SECRET_KEY_BASE=supersecret -e REDMINE_DB_POSTGRES=redminedb -e REDMINE_DB_DATABASE=postgres -e REDMINE_DB_USERNAME=postgres -e REDMINE_DB_PASSWORD=${dbpass} redmine
exit
}

parse_params() {
 # default values of variables set from params
 flag=0
 param=''

 while :; do
 case "${1-}" in
 -h | --help) usage ;;
 -v | --verbose) set -x ;;
 --no-color) NO_COLOR=1 ;;
 -i | --install) install ;;
 -p | --prepare) prepare ;;
 -c | --cleanup) setmsg
 param="${2-}"
 shift
 ;;
 -?*) die "Unknown option: $1" ;;
 *) break ;;
 esac
 shift
 done

 args=("$@")

 # check required params and arguments
##### [[ -z "${param-}" ]] && die "Missing required parameter: param"
##### [[ ${#args[@]} -eq 0 ]] && die "Missing script arguments"

 return 0

}

setup_colors
parse_params "$@"

#setup_colors

# script logic here

msg "${RED}Read parameters:${NOFORMAT}"
msg "- flag: ${flag}"
msg "- param: ${param}"
msg "- arguments: ${args[*]-}"
