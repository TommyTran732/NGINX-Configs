# NGINX Setup

![ShellCheck](https://github.com/Metropolis-Nexus/NGINX-Setup/actions/workflows/shellcheck.yml/badge.svg)

NGINX configurations meant for deployment on Fedora CoreOS.

**Note:** While it is possible to combine https and stream in a single VM, Metropolis.nexus uses 2 separate VMs to keep the config simple and be more efficient.

## Deployment

- Install required dependencies: 

```bash
sudo rpm-ostree install certbot nginx policycoreutils-python-utils
sudo reboot
```

- Run `setup.sh`
- Generate a certificate with the `certbot-command` example
- Copy `/etc/nginx/conf.d/default-quic` from the repo and adjust accordingly

## Stream Deployment

- Install required dependencies:

```bash
sudo rpm-ostree install certbot nginx-mod-stream policycoreutils-python-utils
```
- Run `setup.sh`
- Generate a certificate with the `certbot-command` example
- Copy `/etc/nginx/stream.d/default` from the repo and adjust accordingly
