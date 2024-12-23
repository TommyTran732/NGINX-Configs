#!/bin/sh

# Copyright (C) 2024 Thien Tran
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

set -eu

output(){
    printf '\e[1;34m%-6s\e[m\n' "${@}"
}

unpriv(){
    sudo -u nobody "$@"
}

ip_pinning_prompt(){
    output 'Do you intend to pin IP addresses in your NGINX config?'
    output 
    output '1) No'
    output '2) Yes'
    output 'Insert the number of your selection:'
    read -r choice
    case $choice in
        1 ) ip_pinning=0
            ;;
        2 ) ip_pinning=1
            ;;
        * ) output 'You did not enter a valid selection.'
            ip_pinning_prompt
    esac
}

ip_pinning_prompt

# Allow reverse proxy
sudo setsebool -P httpd_can_network_connect 1

# Allow QUIC
sudo semanage port -a -t http_port_t -p udp 443

# Open ports for NGINX
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-port=443/udp
sudo firewall-cmd --reload

if [ "${ip_pinning}" = '1' ]; then
    # Add 99-nonlocal-bind.conf
    # This fixes a long standing bug where network-online.target is reached before IPv6 is obtained, which breaks IPv6 pinning.
    # Also, if you are using floating IPs for NGINX stream like I do, you need it anyways
    unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/sysctl.d/99-nonlocal-bind.conf | sudo tee /etc/sysctl.d/99-nonlocal-bind.conf > /dev/null
    sudo chmod 644 /etc/sysctl.d/99-nonlocal-bind.conf
fi

# Setup webroot for NGINX
## Explicitly using /var/srv here because SELinux does not follow symlinks
sudo semanage fcontext -a -t httpd_sys_content_t "$(realpath /srv/nginx)(/.*)?"
sudo mkdir -p /srv/nginx/.well-known/acme-challenge
sudo chmod -R 755 /srv/nginx
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/srv/nginx/ads.txt | sudo tee /srv/nginx/ads.txt > /dev/null
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/srv/nginx/app-ads.txt | sudo tee /srv/nginx/app-ads.txt > /dev/null
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/srv/nginx/robots.txt | sudo tee /srv/nginx/robots.txt > /dev/null
sudo chmod 644 /srv/nginx/ads.txt /srv/nginx/app-ads.txt /srv/nginx/robots.txt
sudo restorecon -Rv "$(realpath /srv/nginx)"

# NGINX hardening
sudo mkdir -p /etc/systemd/system/nginx.service.d
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/nginx.service.d/local.conf | sudo tee /etc/systemd/system/nginx.service.d/override.conf > /dev/null
sudo chmod 644 /etc/systemd/system/nginx.service.d/override.conf
sudo systemctl daemon-reload

# Setup nginx-create-session-ticket-keys

if grep -q rhel /etc/os-release; then
    unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/scripts/nginx-create-session-ticket-keys-ramfs | sudo tee /usr/local/bin/nginx-create-session-ticket-keys > /dev/null
else
    unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/nginx-create-session-ticket-keys | sudo tee /usr/local/bin/nginx-create-session-ticket-keys > /dev/null
fi

## Set the appropriate SELinux context for session ticket keys creation
sudo semanage fcontext -a -t bin_t "$(realpath /usr/local/bin/nginx-create-session-ticket-keys)"
sudo restorecon "$(realpath /usr/local/bin/nginx-create-session-ticket-keys)"
sudo chmod u+x "$(realpath /usr/local/bin/nginx-create-session-ticket-keys)"
sudo sed -i '$i restorecon -Rv /etc/nginx/session-ticket-keys' "$(realpath /usr/local/bin/nginx-create-session-ticket-keys)"

# Set the appropriate SELinux context for session ticket keys rotation
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/nginx-rotate-session-ticket-keys | sudo tee /usr/local/bin/nginx-rotate-session-ticket-keys > /dev/null
sudo semanage fcontext -a -t bin_t "$(realpath /usr/local/bin/nginx-rotate-session-ticket-keys)"
sudo restorecon -Rv "$(realpath /usr/local/bin/nginx-rotate-session-ticket-keys)"
sudo chmod u+x "$(realpath /usr/local/bin/nginx-rotate-session-ticket-keys)"
sudo sed -i '$i restorecon -Rv /etc/nginx/session-ticket-keys' "$(realpath /usr/local/bin/nginx-rotate-session-ticket-keys)"

# Download the units
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/refs/heads/main/etc/systemd/system/nginx-session-ticket-keys.mount | sudo tee /etc/systemd/system/nginx-session-ticket-keys.mount > /dev/null
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/nginx-create-session-ticket-keys.service | sudo tee /etc/systemd/system/nginx-create-session-ticket-keys.service > /dev/null
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/nginx-rotate-session-ticket-keys.service | sudo tee /etc/systemd/system/nginx-rotate-session-ticket-keys.service > /dev/null
unpriv curl -s https://raw.githubusercontent.com/GrapheneOS/infrastructure/main/systemd/system/nginx-rotate-session-ticket-keys.timer | sudo tee /etc/systemd/system/nginx-rotate-session-ticket-keys.timer > /dev/null

# Systemd Hardening
sudo mkdir -p /etc/systemd/system/nginx.service.d /etc/systemd/system/certbot-renew.service.d
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/systemd/system/nginx.service.d/override.conf | sudo tee /etc/systemd/system/nginx.service.d/override.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/systemd/system/certbot-renew.service.d/override.conf | sudo tee /etc/systemd/system/certbot-renew.service.d/override.conf > /dev/null
sudo systemctl daemon-reload

# Enable the units
sudo systemctl enable --now nginx-session-ticket-keys.mount
sudo systemctl enable --now nginx-create-session-ticket-keys.service
sudo systemctl enable --now nginx-rotate-session-ticket-keys.timer

# Download NGINX configs

unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/conf.d/http2.conf | sudo tee /etc/nginx/conf.d/http2.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/conf.d/server_tokens.conf | sudo tee /etc/nginx/conf.d/server_tokens.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/conf.d/default.conf | sudo tee /etc/nginx/conf.d/default.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/conf.d/tls.conf | sudo tee /etc/nginx/conf.d/tls.conf > /dev/null

sudo mkdir -p /etc/nginx/snippets
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/hsts.conf | sudo tee /etc/nginx/snippets/hsts.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/proxy.conf | sudo tee /etc/nginx/snippets/proxy.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/quic.conf | sudo tee /etc/nginx/snippets/quic.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/security.conf | sudo tee /etc/nginx/snippets/security.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/cross-origin-security.conf | sudo tee /etc/nginx/snippets/cross-origin-security.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/robots.conf | sudo tee /etc/nginx/snippets/robots.conf > /dev/null
unpriv curl -s https://raw.githubusercontent.com/TommyTran732/NGINX-Configs/main/etc/nginx/snippets/universal_paths.conf | sudo tee /etc/nginx/snippets/universal_paths.conf > /dev/null

if [ "${ip_pinning}" = '0' ]; then
    sed -i 's/ipv4_1://g' /etc/nginx/conf.d/sites_default.conf
    sed -i 's/ipv6_1/::/g' /etc/nginx/conf.d/sites_default.conf
fi
