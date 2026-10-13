#!/usr/bin/env bash

set -euo pipefail

if ! command -v weechat >/dev/null 2>&1; then
    if ! command -v apt-get >/dev/null 2>&1; then
        printf 'WeeChat is not installed, and apt-get is unavailable.\n' >&2
        exit 1
    fi

    if [[ ${EUID} -eq 0 ]]; then
        apt-get update
        apt-get install -y weechat
    elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y weechat
    else
        printf 'WeeChat is not installed. Install it with apt-get (or configure passwordless sudo) and retry.\n' >&2
        exit 1
    fi
fi

config_dir="${WEECHAT_HOME:-${XDG_CONFIG_HOME:-"$HOME/.config"}/weechat}"
irc_config="${config_dir}/irc.conf"
commands=()

if [[ ! -f "$irc_config" ]] || ! grep -Eq '^undernet\.addresses[[:space:]]*=' "$irc_config"; then
    commands+=(-r '/server add undernet irc.undernet.org/6667 -notls')
fi

commands+=(
    -r '/set irc.server.undernet.addresses irc.undernet.org/6667'
    -r '/set irc.server.undernet.nicks default_nickname'
    -r '/set irc.server.undernet.tls off'
    -r '/connect undernet'
)

exec weechat "${commands[@]}"
