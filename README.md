# NGINX Configs

[![ShellCheck](https://github.com/TommyTran732/NGINX-Configs/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/TommyTran732/NGINX-Configs/actions/workflows/shellcheck.yml)

These are my NGINX configurations. They are written for `nginx-core` on Fedora and mainline NGINX on RHEL.

## Getting Started

1. On Fedora, install `nginx-core`, `certbot` and `policycoreutils-python-utils`. On RHEL, install `nginx` from the mainline repository, `certbot`, and `python3-certbot-nginx`. Makesure `rsync` is available on the OS.
2. On Fedora, comment out the default server block in `/etc/nginx/nginx.conf`. On RHEL, move `/etc/nginx/conf.d/default.conf` to `/etc/nginx/conf.d/default.conf.bk`
3. Run `setup.sh`
4. Generate a certificate with your hostname with the `certbot-command` example. Copy `etc/nginx/conf.d/default-quic.conf` to the corresponding directory on your server and edit it approprieately.
5. Generate certificates with the example in the certbot directory.
6. Make your actual vhost config based on the `sites_.*` samples in `/etc/nginx/conf.d`.

## Notes

This is used on my tunnel servers with multiple IP addresses. Hence, you may see addresses like `ipv4_1` and `ipv4_2`. Just replace them with your own ip addresses.
