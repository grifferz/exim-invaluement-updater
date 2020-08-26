#!/usr/bin/env bash

# Generate Exim-format ACL files from Invaluement's SPBL data.
#
# See https://github.com/grifferz/exim-invaluement-updater/ for usage
# instructions and more information.
#
# See https://www.invaluement.com/serviceproviderdnsbl/ for more information
# about Invaluement's SPBL.
#
# Copyright 2020 Andy Smith <andy-exim-invaluement@bitfolk.com>

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

###################################################
### Some user-editable config values start here ###
###################################################

# Default log level is to log warnings and above (2) to stderr. Can be
# overriden by setting LOG_LEVEL in the environment. 5 for debug, 0 for fatal
# messages only.
LOG_LEVEL="${LOG_LEVEL:-2}"

# Default syslog level is to log notices and above (3). Can be overriden by
# setting SYSLOG_LEVEL in the environment. 5 for debug, 0 for fatal messages
# only.
SYSLOG_LEVEL="${SYSLOG_LEVEL:-3}"

# Directory for our data files. This will be created if it doesn't exist. You
# can run this script non-root as long as data_dir already exists and is
# writeable by your user.
data_dir="/var/lib/invaluement-spbl"

# File containing client IDs (so far only SendGrid clients). This is a relative
# path to the data_dir.
id_file="spbl-ids"
id_url="https://www.invaluement.com/spdata/sendgrid-id-dnsbl.txt"

# File containing the domains. This is a relative path to the data_dir.
domain_file="spbl-domains"
domain_url="https://www.invaluement.com/spdata/sendgrid-envelopefromdomain-dnsbl.txt"

#################################################
### No user-editable configuration below here ###
#################################################

progname=$(basename "$0")
eiu_tmp_dir=$(mktemp --tmpdir="${TMPDIR:-/tmp}" --directory "${progname}.XXXXXXXXXXXX")

function _eiu_cleanup () {
    rm -rf "$eiu_tmp_dir"
}

trap _eiu_cleanup EXIT

function _eiu_log () {
    local log_level="${1}"
    shift

    local log_text=""

    while IFS=$'\n' read -r log_text; do
        printf "[%s] %s\n" "${log_level}" "${log_text}" 1>&2
    done <<< "${@:-}"
}

function _eiu_syslog () {
    local log_level="${1}"
    shift

    local log_text=""

    while IFS=$'\n' read -r log_text; do
        printf "[%s] %s\n" "${log_level}" "${log_text}" | logger -t "$progname"
    done <<< "${@:-}"
}

function fatal () {
    _eiu_log    emergency "${@}"
    _eiu_syslog emergency "${@}"
    exit 1
}

function error () {
    [[ "${LOG_LEVEL:-0}"    -ge 1 ]] && _eiu_log    error "${@}"
    [[ "${SYSLOG_LEVEL:-0}" -ge 1 ]] && _eiu_syslog error "${@}"
    true
}

function warn () {
    [[ "${LOG_LEVEL:-0}"    -ge 2 ]] && _eiu_log    warning "${@}"
    [[ "${SYSLOG_LEVEL:-0}" -ge 2 ]] && _eiu_syslog warning "${@}"
    true
}

function notice () {
    [[ "${LOG_LEVEL:-0}"    -ge 3 ]] && _eiu_log    notice "${@}"
    [[ "${SYSLOG_LEVEL:-0}" -ge 3 ]] && _eiu_syslog notice "${@}"
    true
}

function info () {
    [[ "${LOG_LEVEL:-0}"    -ge 4 ]] && _eiu_log    info "${@}"
    [[ "${SYSLOG_LEVEL:-0}" -ge 4 ]] && _eiu_syslog info "${@}"
    true
}

function debug () {
    [[ "${LOG_LEVEL:-0}"    -ge 5 ]] && _eiu_log    debug "${@}"
    [[ "${SYSLOG_LEVEL:-0}" -ge 5 ]] && _eiu_syslog debug "${@}"
    true
}

if ! command -v curl &> /dev/null
then
    fatal "Can't find command 'curl'"
fi

if [ ! -d ${data_dir} ]
then
    mkdir ${data_dir} && notice "Created data directory ${data_dir}"
fi

# If the data files don't exist, create them as empty files with an old
# timestamp so a new one will definitely be downloaded.
if [ ! -f "${data_dir}/${id_file}" -o ! -s "${data_dir}/${id_file}" ]
then
    touch -d "1970-01-01" "${data_dir}/${id_file}" &&
        notice "${id_file} didn't exist - created empty"
fi

if [ ! -f "${data_dir}/${domain_file}" -o ! -s "${data_dir}/${domain_file}" ]
then
    touch -d "1970-01-01" "${data_dir}/${domain_file}" &&
        notice "${domain_file} didn't exist - created empty"
fi

curl --location --silent --time-cond "${data_dir}/${id_file}" "$id_url" |
    sed -e 's/[0-9]\{1,\}/bounces+&-*@sendgrid.net/;t;d' > "$eiu_tmp_dir/id"

if [ -s "$eiu_tmp_dir/id" ]
then
    mv "$eiu_tmp_dir/id" "$data_dir/$id_file"
    info "Invaluement SPBL ID file has been updated"
else
    debug "No newer Invaluement SPBL ID file available"
fi

curl --location --silent --time-cond "${data_dir}/${domain_file}" "$domain_url" |
    sed -e 's/^[^#]\{1,\}/*@*.&/;t;d' > "$eiu_tmp_dir/domain"

if [ -s "$eiu_tmp_dir/domain" ]
then
    mv "$eiu_tmp_dir/domain" "$data_dir/$domain_file"
    info "Invaluement SPBL domains file has been updated"
else
    debug "No newer SPBL domains file available"
fi
