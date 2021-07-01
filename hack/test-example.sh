#!/usr/bin/env bash
set -eu -o pipefail

function INFO() {
	echo "TEST| [INFO] $*"
}

function WARNING() {
	echo >&2 "TEST| [WARNING] $*"
}

function ERROR() {
	echo >&2 "TEST| [ERROR] $*"
}

if [[ ${BASH_VERSINFO:-0} -lt 4 ]]; then
	ERROR "Bash version is too old: ${BASH_VERSION}"
	exit 1
fi

if [ "$#" -ne 1 ]; then
	ERROR "Usage: $0 FILE.yaml"
	exit 1
fi

FILE="$1"
NAME="$(basename -s .yaml "$FILE")"

INFO "Validating \"$FILE\""
limactl validate "$FILE"

declare -A CHECKS=(
	["systemd"]="1"
	["systemd-strict"]="1"
	["mount-home"]="1"
	["containerd-user"]="1"
	["restart"]="1"
)

case "$NAME" in
"alpine")
	WARNING "Alpine does not support systemd"
	CHECKS["systemd"]=
	CHECKS["containerd-user"]=
	;;
"k3s")
	ERROR "File \"$FILE\" is not testable with this script"
	exit 1
	;;
"fedora")
	WARNING "Relaxing systemd tests for fedora (For avoiding CI faillure)"
	# CI failure:
	# ● run-r2b459797f5b04262bfa79984077a65c7.service                                       loaded failed failed    /usr/bin/systemctl start man-db-cache-update
	CHECKS["systemd-strict"]=
	;;
esac

if limactl ls -q | grep -q "$NAME"; then
	ERROR "Instance $NAME already exists"
	exit 1
fi

INFO "Starting \"$NAME\" from \"$FILE\""
trap 'limactl delete -f $NAME' EXIT
set -x
if ! limactl start --tty=false "$FILE"; then
	ERROR "Failed to start \"$NAME\""
	tail "$HOME/.lima/${NAME}"/*.log
	limactl shell "$NAME" systemctl status || true
	limactl shell "$NAME" cat /var/log/cloud-init-output.log || true
	exit 1
fi

limactl shell "$NAME" uname -a

limactl shell "$NAME" cat /etc/os-release
set +x

INFO "Testing limactl copy command"
tmpfile="$HOME/lima-hostname"
rm -f "$tmpfile"
limactl cp "$NAME":/etc/hostname "$tmpfile"
trap 'rm -f $tmpfile' EXIT
expected="$(limactl shell "$NAME" cat /etc/hostname)"
got="$(cat "$tmpfile")"
INFO "/etc/hostname: expected=${expected}, got=${got}"
if [ "$got" != "$expected" ]; then
	ERROR "copy command did not fetch the file"
	exit 1
fi

if [[ -n ${CHECKS["systemd"]} ]]; then
	set -x
	if ! limactl shell "$NAME" systemctl is-system-running --wait; then
		ERROR '"systemctl is-system-running" failed'
		limactl shell "$NAME" systemctl
		if [[ -z ${CHECKS["systemd-strict"]} ]]; then
			INFO 'Ignoring "systemctl is-system-running" failure'
		else
			exit 1
		fi
	fi
	set +x
fi

if [[ -n ${CHECKS["mount-home"]} ]]; then
	hometmp="$HOME/lima-test-tmp"
	INFO "Testing home access (\"$hometmp\")"
	rm -rf "$hometmp"
	mkdir -p "$hometmp"
	trap 'rm -rf $hometmp' EXIT
	echo "random-content-${RANDOM}" >"$hometmp/random"
	expected="$(cat "$hometmp/random")"
	got="$(limactl shell "$NAME" cat "$hometmp/random")"
	INFO "$hometmp/random: expected=${expected}, got=${got}"
	if [ "$got" != "$expected" ]; then
		ERROR "Home directory is not shared?"
		exit 1
	fi
fi

if [[ -n ${CHECKS["containerd-user"]} ]]; then
	INFO "Run a nginx container with port forwarding 127.0.0.1:8080"
	set -x
	limactl shell "$NAME" nerdctl info
	# Use GHCR to avoid hitting Docker Hub rate limit
	nginx_image="ghcr.io/stargz-containers/nginx:1.19-alpine-org"
	limactl shell "$NAME" sh -ec "nerdctl pull ${nginx_image} >/dev/null"
	limactl shell "$NAME" nerdctl run -d --name nginx -p 127.0.0.1:8080:80 ${nginx_image}

	timeout 3m bash -euxc "until curl -f --retry 30 --retry-connrefused http://127.0.0.1:8080; do sleep 3; done"

	limactl shell "$NAME" nerdctl rm -f nginx
	set +x
fi

if [[ -n ${CHECKS["restart"]} ]]; then
	INFO "Create file in the guest home directory and verify that it still exists after a restart"
	# shellcheck disable=SC2016
	limactl shell "$NAME" sh -c 'touch $HOME/sweet-home'

	INFO "Stopping \"$NAME\""
	limactl stop "$NAME"

	INFO "Restarting \"$NAME\""
	limactl start "$NAME"

	# shellcheck disable=SC2016
	if ! limactl shell "$NAME" sh -c 'test -f $HOME/sweet-home'; then
		ERROR "Guest home directory does not persist across restarts"
		exit 1
	fi
fi

INFO "Stopping \"$NAME\""
limactl stop "$NAME"

INFO "Deleting \"$NAME\""
limactl delete "$NAME"
