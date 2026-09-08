#!/bin/sh
set -eu

apk add --no-cache curl >/dev/null

check_via_tunnel() {
  HOST="$1"
  PATH_="$2"
  EXPECTED="$3"

  # nslookup returns both A and AAAA records; grabbing the last line
  # blindly picks up the IPv6 one, which curl's --resolve rejects
  # unbracketed -- filter to an IPv4-shaped address specifically.
  PUBLIC_IP=$(nslookup "$HOST" 1.1.1.1 2>/dev/null | awk '/^Address: / {print $2}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)

  if [ -z "$PUBLIC_IP" ]; then
    echo "FAIL: could not resolve $HOST via public DNS (1.1.1.1)"
    exit 1
  fi

  STATUS=$(curl -s -o /dev/null -w "%{http_code}" --resolve "$HOST:443:$PUBLIC_IP" "https://$HOST$PATH_")

  if [ "$STATUS" != "$EXPECTED" ]; then
    echo "FAIL: expected status $EXPECTED from https://$HOST$PATH_ via the Cloudflare tunnel (resolved $PUBLIC_IP), got $STATUS"
    exit 1
  fi

  echo "PASS: $HOST reachable through the Cloudflare tunnel, returned $STATUS"
}

check_via_tunnel "argocd.morrisons.site" "/healthz" "200"
check_via_tunnel "woodpecker.morrisons.site" "/healthz" "204"
