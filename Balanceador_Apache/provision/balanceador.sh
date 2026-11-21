#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y apache2 ufw curl certbot python3-certbot-apache
systemctl disable --now haproxy || true
a2enmod proxy proxy_http proxy_balancer lbmethod_byrequests
cat > /etc/apache2/sites-available/load-balancer.conf <<'CFG'
<VirtualHost *:80>
    ServerName rmunnozg15.ddns.net
    ProxyPreserveHost On

    # Keep ACME HTTP-01 validation on the frontend, not the web backends.
    ProxyPass "/.well-known/acme-challenge/" "!"
    Alias "/.well-known/acme-challenge/" "/var/lib/letsencrypt/.well-known/acme-challenge/"
    <Directory "/var/lib/letsencrypt/.well-known/acme-challenge/">
        Options None
        AllowOverride None
        Require all granted
    </Directory>

    <Proxy "balancer://webcluster">
        BalancerMember "http://192.168.56.11:80"
        BalancerMember "http://192.168.56.12:80"
        ProxySet lbmethod=byrequests
    </Proxy>

    ProxyPass        "/" "balancer://webcluster/"
    ProxyPassReverse "/" "balancer://webcluster/"
</VirtualHost>
CFG
mkdir -p /var/lib/letsencrypt/.well-known/acme-challenge
a2dissite 000-default.conf || true
a2ensite load-balancer.conf
apachectl configtest
systemctl enable --now apache2
systemctl reload apache2
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
# Prefer the bridged Wi-Fi interface for public responses. This keeps replies
# to inbound HTTP/HTTPS connections on the same network path as the requests.
install -m 600 /dev/null /etc/netplan/99-balanceador-route.yaml
cat > /etc/netplan/99-balanceador-route.yaml <<'NETPLAN'
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s9:
      dhcp4: false
      routes:
        - to: default
          via: 192.168.0.1
          metric: 50
      nameservers:
        addresses: [192.168.0.1, 1.1.1.1]
NETPLAN
netplan generate
netplan apply
# Wait until both web applications and their MariaDB connection are ready.
web1_ready=false
web2_ready=false
for attempt in $(seq 1 90); do
    if [[ "$web1_ready" != true ]] && curl -fs --connect-timeout 2 http://192.168.56.11/ | grep -Fq 'Conexión correcta con MariaDB'; then
        web1_ready=true
        echo "Web1 y MariaDB están listos."
    fi
    if [[ "$web2_ready" != true ]] && curl -fs --connect-timeout 2 http://192.168.56.12/ | grep -Fq 'Conexión correcta con MariaDB'; then
        web2_ready=true
        echo "Web2 y MariaDB están listos."
    fi
    if [[ "$web1_ready" == true && "$web2_ready" == true ]]; then
        break
    fi
    sleep 2
done
if [[ "$web1_ready" != true || "$web2_ready" != true ]]; then
    echo "ERROR: Web1, Web2 o MariaDB no respondieron durante el aprovisionamiento." >&2
    exit 1
fi
curl -fs http://127.0.0.1/ | grep -Fq 'Conexión correcta con MariaDB'
echo "Balanceador Apache listo en el puerto 80."
# Automatic HTTPS setup for a fresh VM. If public HTTP-01 validation cannot
# reach this VM, keep HTTP working and print the manual command for later.
if [[ ! -s /etc/letsencrypt/live/rmunnozg15.ddns.net/fullchain.pem ]]; then
    echo "Solicitando certificado HTTPS para rmunnozg15.ddns.net..."
    if ! certbot --apache --non-interactive --agree-tos --register-unsafely-without-email -d rmunnozg15.ddns.net; then
        echo "AVISO: Certbot no pudo validar el dominio. HTTP sigue disponible; comprueba DNS y el reenvío TCP 80/443 y vuelve a ejecutar: sudo certbot --apache -d rmunnozg15.ddns.net" >&2
    fi
else
    echo "Ya existe un certificado válido; no se solicita otro."
fi
