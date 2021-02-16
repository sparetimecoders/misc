#!/usr/bin/env bash
set -euo pipefail

TEMP=`/usr/local/opt/gnu-getopt/bin/getopt -o vdm: --long output:,private,context:,prefix:,bastion:,key:,forwards: -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

kube_cmd="kubectl --context docker-desktop"

context=''
private=false
bastion=''
file=''
prefix=''
key='~/.ssh/id_rsa'
ssh_user='admin'
declare -a forwards

while true; do
  case "$1" in
    --context ) context="${2}"; shift 2;;
    --prefix ) prefix="${2}"; shift 2;;
    --bastion ) bastion="${2}"; private=true; shift 2;;
    --key ) key="${2}"; shift 2;;
    --forwards ) forwards+=("${2}"); shift 2;;
    --private ) private=true; shift ;;
    --output ) file="${2}"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done
if [ "${context}" = "" ]; then echo "context parameter missing..." >&2 ; exit 1 ; fi
if [ "${prefix}" == "" ]; then prefix="${context}"; fi

bastion_name="bastion_${prefix}"

get_ips() {
    jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}'
    if [ "$private" == true ]; then
        jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'
    fi

    kubectl --context ${context} get node \
        --selector='!node-role.kubernetes.io/master' \
        -o jsonpath="${jsonpath}"
}

default_host() {
echo "
Host ${prefix}_*
  User admin
  IdentityFile ${key}
"
}

bastion_host() {
echo "
Host ${bastion_name}
  User admin
  IdentityFile ${key}
  HostName ${bastion}

Host ${prefix}_*
  User admin
  IdentityFile ${key}
  ProxyJump ${bastion_name}
"
}

hosts() {
  count=0
  for host in $(get_ips); do 
    count=$((count+1))
echo "
Host ${prefix}_node_${count}
  HostName ${host}" 
    for forward in "${forwards[@]}"; do
      echo "  ${forward}"
    done
  done
}

hosts
if [ "${private}" == "true" ]; then bastion_host; else default_host; fi
