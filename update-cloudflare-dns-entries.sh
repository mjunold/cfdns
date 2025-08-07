#!/bin/bash

# Update Cloudflare IPv4 and IPv6 dns entries

IPV4ADDR="$(curl -s https://api.ipify.org/)"
IPV6ADDR="$(curl -s https://api6.ipify.org/)"

APITOKEN="$(cat ~/cfdns/cloudflare-api-token.txt)"
if [ -z "${APITOKEN}" ]; then
  echo "API token not found. Please create a file at ~/cfdns/cloudflare-api-token.txt with your Cloudflare API token."
  exit 1
fi

while read DOMAINNAME RECORDTYPE TTL PROXIED ZONEID RECORDID; do

        CURRSETIPV4ADDR="$(dig +short ${DOMAINNAME} A | tail -n1)"
        CURRSETIPV6ADDR="$(dig +short ${DOMAINNAME} AAAA | tail -n1)"

        if [ "${RECORDTYPE}" == "A" ]; then
          IP=${IPV4ADDR}
          CURRSETIP=${CURRSETIPV4ADDR}
        elif [ "${RECORDTYPE}" == "AAAA" ]; then
          IP=${IPV6ADDR}
          CURRSETIP=${CURRSETIPV6ADDR}
        fi

        if [ ${IP} == ${CURRSETIP} ]; then
          printf "No update needed for ${DOMAINNAME} (${RECORDTYPE})"
          printf "\n"
          continue
        fi

        printf "Updating ${DOMAINNAME} (${RECORDTYPE}) from ${CURRSETIP} to ${IP}"

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

done < ~/cfdns/cloudflare-dns-entries.txt
