#!/usr/bin/env bash
set -euo pipefail

# Runs as an unprivileged user. Does not require sudo. Clones and builds server and web frontend
# into the ~/starscape directory, and enables a user systemd service that runs starscape. Pulls and
# builds updates if the update argument is given

case ${1:-no_arg} in
"update")
  UPDATE=1
  ;;
"no_arg")
  UPDATE=0
  ;;
*)
  printf "${RED}unknown command $1${NORMAL}\n"
  exit 1
  ;;
esac

# -j1 can be removed on CPU's that aren't RAM-constrained
CARGO_BUILD_ARGS=(-j1)

HOME=$(cd ~ && pwd) # If run with sudo $HOME might be wrong
STARSCAPE_HOME="$HOME/starscape"
STARSCAPE_BIN_PATH="$STARSCAPE_HOME/server-bin"
STARSCAPE_PUBLIC_PATH="$STARSCAPE_HOME/public"
# BASH magic to get the directory of this script
SELF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

NORMAL="\x1b[0m"
EOL="${NORMAL}\n"
BLUE="\x1b[34m"
GREEN="\x1b[32m"
RED="\x1b[31m"

check_deps() {
  for DEP in "$@"; do
    if ! which "$DEP" &>/dev/null; then
      printf "${RED}$DEP not installed$EOL"
      exit 1
    fi
  done
}

setup_server() {
  if test ! -e server; then
    printf "${BLUE}cloning starscape server...$EOL"
    git clone https://github.com/OpenStarscape/starscape-server.git server
  elif test $UPDATE == 1; then
    printf "${BLUE}pulling starscape server...$EOL"
    git -C server pull
  fi
  cd server
  BUILT_BIN_PATH="target/release/starscape-server"
  if test $UPDATE == 1 -o ! -e "$BUILT_BIN_PATH"; then
    printf "${BLUE}building starscape server...$EOL"
    check_deps cargo rustc
    if ! cargo build --release "${CARGO_BUILD_ARGS[@]}"; then
      echo
      printf "${RED}cargo build failed. updating your rust toolchain or deleting $STARSCAPE_HOME/server may fix the problem$EOL"
      exit 1
    fi
  fi
  printf "${BLUE}copying binary to %s...$EOL" "$STARSCAPE_BIN_PATH"
  cp "$BUILT_BIN_PATH" "$STARSCAPE_BIN_PATH"
  cd "$STARSCAPE_HOME"
}

setup_web() {
  if test ! -e web; then
    printf "${BLUE}cloning starscape web...$EOL"
    git clone https://github.com/OpenStarscape/starscape-web.git web
  elif test $UPDATE == 1; then
    printf "${BLUE}pulling starscape web...$EOL"
    git -C web pull
  fi
  cd web
  if test $UPDATE == 1 -o ! -e "public/code.js"; then
    printf "${BLUE}building starscape web...$EOL"
    check_deps yarn node
    if ! yarn || ! yarn prod-build; then
      echo
      printf "${RED}yarn failed. updating yarn and node or deleting $STARSCAPE_HOME/web may fix the problem$EOL"
      exit 1
    fi
  fi
  printf "${BLUE}copying public directory to %s...$EOL" "$STARSCAPE_PUBLIC_PATH"
  rm -Rf "$STARSCAPE_PUBLIC_PATH"
  cp -R public "$STARSCAPE_PUBLIC_PATH"
  cd "$STARSCAPE_HOME"
}

setup_service() {
  if systemctl --user status starscape &>/dev/null; then
    systemctl --user stop starscape
  fi
  SERVICE_FILE="$HOME/.config/systemd/user/starscape.service"
  printf "${BLUE}copying service file to %s...$EOL" "$SERVICE_FILE"
  mkdir -p "$(dirname "$SERVICE_FILE")"
  cp "$SELF_DIR/starscape.service" "$SERVICE_FILE"
  printf "${BLUE}reloading and enabling service...$EOL"
  systemctl --user daemon-reload
  systemctl --user enable --now starscape
  sleep 0.5
  if ! systemctl --user status starscape --no-pager; then
    journalctl --user -u starscape -n 30 --no-pager
    printf "${RED}starscape service failed$EOL"
    exit 1
  fi
}

mkdir -p "$STARSCAPE_HOME"
cd "$STARSCAPE_HOME"
printf "${BLUE}setting up OpenStarscape server in %s$EOL" "$STARSCAPE_HOME"
if test ! -e "$STARSCAPE_HOME/starscape.toml"; then
  printf "${BLUE}copying server configuration file...$EOL" "$STARSCAPE_BIN_PATH"
  cp "$SELF_DIR/starscape.toml" "$STARSCAPE_HOME/starscape.toml"
fi
if test $UPDATE == 1 -o ! -e "$STARSCAPE_BIN_PATH"; then
  setup_server
fi
if test $UPDATE == 1 -o ! -e "$STARSCAPE_PUBLIC_PATH"; then
  setup_web
fi
setup_service

printf "
${GREEN}OpenStarscape should now be running with the configuration specified in $STARSCAPE_HOME/starscape.toml.$NORMAL
To stop it, run:

${RED}$ systemctl --user disable --now starscape$NORMAL

This script is idempotent, meaning running it again won't fuck everything up. Additional web
server setup (such as nginx, TLS certs, etc) is out of scope of this script. See readme.md for
more documentation and suggestions on next steps.
"
