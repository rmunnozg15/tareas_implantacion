#!/usr/bin/env bash
set -euo pipefail
LETSENCRYPT_DOMAIN=rmunnozg15.ddns.net
LETSENCRYPT_EMAIL=rmunnozg15@iesalbarregas.es
if [[ -f /vagrant/scripts/.env ]]; then set -a; source /vagrant/scripts/.env; set +a; fi
[[ -n "$LETSENCRYPT_DOMAIN" && -n "$LETSENCRYPT_EMAIL" ]] || { echo "Define dominio y correo en scripts/.env."; exit 2; }
echo "Requisitos: DNS público correcto y reenvío TCP 80 del router a esta VM."
read -r -p "¿Está comprobado el acceso HTTP desde Internet? [s/N] " answer
[[ "$answer" =~ ^[sS]$ ]] || { echo "Solicitud cancelada."; exit 0; }
certbot --apache --non-interactive --agree-tos --redirect --email "$LETSENCRYPT_EMAIL" -d "$LETSENCRYPT_DOMAIN"
certbot certificates
