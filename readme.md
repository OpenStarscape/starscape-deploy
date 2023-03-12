# Scarscape Deploy
Scripts, files and documentation for deploying an OpenStarscape server

## Scope
This repo contains opinionated documentation and automation for building and deploying deploying [OpenStarscape](https://github.com/OpenStarscape). on a Linux server. It's not the only way, doing things differently should work fine.

## Dependencies
`setup.sh` requires `cargo`, `rustc`, `yarn` and `node` to be installed. It's recommended to have the latest version of each.

## setup.sh
[setup.sh](setup.sh) is a bash script that is generally run as an unprivileged user. It does the following:
- Creates `~/starscape` (if it doesn't already exist)
- Creates `~/starscape/starscape.toml` (if it doesn't already exists)
- If `~/starscape/server-bin` does not exist:
    - Clones the server into `~/starscape/server` (if needed)
    - Builds the server (if needed)
    - Copies the server binary to `~/starscape/server-bin`
- If `~/starscape/public` does not exist:
    - Clones the web frontend into `~/starscape/web` (if needed)
    - Builds the web frontend (if needed)
    - Copies the web frontend to `~/starscape/public`
- Copies the systemd user service to `~/.config/systemd/user/starscape.service`
- Starts and enables the `starscape` user service

## Managing the Service
`setup.sh` runs Starscape as a systemd user service. This service only runs when the user is logged in, to have it work when the user isn't logged in run:
```
loginctl enable-linger
```
To check the status of the service, run:
```
systemctl --user status starscape
```
To see the logs, run:
```
journalctl --user -u starscape -e
```
To stop the service, and prevent it from running after future reboots, run:
```
systemctl --user disable --now starscape
```
Running `setup.sh` again will restart and re-enable it.

## Web server
It's recommended you use a web server, such as nginx. You can base your nginx configuration on the provided nginx.conf. It's recommended that your web server handles TLS and HTTPS redirection if desired (this functionality is currently in Starscape as well, but is likely to be removed). Getting TLS set up can be as simple as:
```
$ apt install certbot
$ certbot --nginx
# Follow instructions
```

__Loopback:__ this repo's starscape.toml has http_loopback enabled. This is required for it to work with nginx, however if you're not using a 3rd party web server and want Starscape to be accessible outside of the current machine this option needs to be disabled.

## Configuration
To configure Starscape, edit `~/starscape/starscape.toml` and then run `systemctl --user restart starscape`. Running `~/starscape/server-bin --help` will show you a list of configuration options.

## Updating
`setup.sh` currently does not pull, nor does it re-build if there is already an outdated build. The best way to update is to wipe `~/starscape` and re-run `setup.sh`. Improvements to this are planned.

## Uninstalling
Run the following:
```
systemctl --user disable --now starscape
rm ~/.config/systemd/user/starscape.service
rm -Rf ~/starscape
```
And remove any additional files you may have installed (such as web server configuration files)
