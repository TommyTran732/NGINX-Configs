# NGINX Setup

![ShellCheck](https://github.com/Metropolis-Nexus/NGINX-Setup/actions/workflows/shellcheck.yml/badge.svg)

NGINX configurations meant for deployment on Fedora CoreOS.

## Deployment

- Install required dependencies: 

```bash
sudo rpm-ostree install certbot nginx-core nginx-mod-stream policycoreutils-python-utils
```

- Comment out the default server block in `/etc/nginx/nginx.conf`
- Run `setup.sh`
- Generate a certificate with the `certbot-command` example
- Copy `/etc/nginx/conf.d/default-quic` from the repo and adjust accordingly