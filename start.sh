#!/bin/sh

docker run \
    --name ikev2-vpn-server \
    -p 500:500/udp \
    -p 4500:4500/udp \
    -v /lib/modules:/lib/modules:ro \
    --cap-add=NET_ADMIN \
    -v "$PWD/data/etc/ipsec.d/ipsec.secrets:/usr/local/etc/ipsec.secrets" \
    --env-file "$PWD/.env" \
    -v /lib/modules:/lib/modules:ro \
    -d --privileged \
    --restart=always \
    drzhnin/docker-ikev2-vpn-server
