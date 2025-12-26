#!/bin/bash

# Update Cloudflare IPv4 and IPv6 dns entries

IPV4ADDR="$(curl -s https://api.ipify.org/)"
IPV6ADDR="$(curl -s https://api6.ipify.org/)"

WORKPATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APITOKEN="$(cat ${WORKPATH}/cloudflare-api-token.txt)"
if [ -z "${APITOKEN}" ]; then
  echo "API token not found. Please create a file at ${WORKPATH}/cloudflare-api-token.txt with your Cloudflare API token."
  exit 1
fi

# Default: do not force updates when IPs match
FORCE=false

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --force|-f)
      FORCE=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--force]"
      echo "  --force, -f   Force update even if IP unchanged"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

while read DOMAINNAME RECORDTYPE TTL PROXIED ZONEID RECORDID; do

        CFIP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONEID/dns_records/$RECORDID" \
          -H "Authorization: Bearer $APITOKEN" \
          -H "Content-Type: application/json" \
          | jq -er '.result.content') || {
            echo "❌ Failed to get IP address from Cloudflare API."
            exit 1
        }

        if [[ -z "$CFIP" ]]; then
            echo "❌ IP address is empty. Something went wrong."
            exit 1
        fi

        echo "Currently set IP: $CFIP"

        if [ "${RECORDTYPE}" == "A" ]; then
          IP=${IPV4ADDR}
        elif [ "${RECORDTYPE}" == "AAAA" ]; then
          IP=${IPV6ADDR}
        fi

        if [ "${FORCE}" != "true" ] && [ "${IP}" == "${CFIP}" ]; then
          printf "No update needed for ${DOMAINNAME} (${RECORDTYPE})"
          printf "\n"
          continue
        fi

        printf "Updating ${DOMAINNAME} (${RECORDTYPE}) from ${CFIP} to ${IP}"

        # Update the DNS record using Cloudflare API
        curl -s --request PUT \
          --url https://api.cloudflare.com/client/v4/zones/${ZONEID}/dns_records/${RECORDID} \
          --header 'Content-Type: application/json' \
          --header 'X-Auth-Email: ' \
          --header 'Authorization: Bearer '"${APITOKEN}" \
          --data '{
                  "comment": "Domain record set at '"$(date +%Y%m%d-%H:%M:%S.%s)"'",
                  "name": "'"${DOMAINNAME}"'",
                  "proxied": '"${PROXIED}"',
                  "settings": {},
                  "tags": [],
                  "ttl": '"${TTL}"',
                  "content": "'"${IP}"'",
                  "type": "'"${RECORDTYPE}"'"
        }'

        printf "\n"

done < ${WORKPATH}/cloudflare-dns-entries.txt
