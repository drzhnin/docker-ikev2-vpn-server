#!/bin/bash

VPNIPPOOL="10.15.1.0/24"
LEFT_ID=${VPNHOST}

sysctl net.ipv4.ip_forward=1
sysctl net.ipv6.conf.all.forwarding=1
sysctl net.ipv6.conf.eth0.proxy_ndp=1

tc qdisc del dev eth0 root
tc qdisc add dev eth0 root handle 1: htb
for i in {1..254}
do
iptables -I FORWARD -s 10.15.1.$i -j MARK --set-mark 1$i
iptables -I FORWARD -d 10.15.1.$i -j MARK --set-mark 1$i
tc class add dev eth0 parent 1:1 classid 1:1$i htb rate 1mbit ceil 1mbit
tc qdisc add dev eth0 parent 1:1$i sfq perturb 10
tc filter add dev eth0 protocol ip parent 1: prio 1 handle 1$i fw flowid 1:1$i
done

iptables -t nat -A POSTROUTING -s ${VPNIPPOOL} -o eth0 -m policy --dir out --pol ipsec -j ACCEPT
iptables -t nat -A POSTROUTING -s ${VPNIPPOOL} -o eth0 -j MASQUERADE

iptables -L

if [[ ! -f "/usr/local/etc/ipsec.d/certs/fullchain.pem" && ! -f "/usr/local/etc/ipsec.d/private/privkey.pem" ]] ; then
    certbot certonly --standalone --preferred-challenges http --agree-tos --no-eff-email --email ${LEEMAIL} -d ${VPNHOST}
    cp /etc/letsencrypt/live/${VPNHOST}/fullchain.pem /usr/local/etc/ipsec.d/certs
    cp /etc/letsencrypt/live/${VPNHOST}/privkey.pem /usr/local/etc/ipsec.d/private
fi

if [ ! -f "/usr/local/etc/ipsec.d/cacerts/lets-encrypt-x3-cross-signed.pem" ]; then
    wget -P /usr/local/etc/ipsec.d/cacerts https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem
fi

rm -f /var/run/starter.charon.pid

if [ -f "/usr/local/etc/ipsec.conf" ]; then
rm /usr/local/etc/ipsec.conf
cat >> /usr/local/etc/ipsec.conf <<EOF
config setup
    charondebug="ike 1, knl 1, cfg 1"
    uniqueids=no
conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    ike=aes128-sha1-modp1024,aes128-sha1-modp1536,aes128-sha1-modp2048,aes128-sha256-ecp256,aes128-sha256-modp1024,aes128-sha256-modp1536,aes128-sha256-modp2048,aes256-aes128-sha256-sha1-modp2048-modp4096-modp1024,aes256-sha1-modp1024,aes256-sha256-modp1024,aes256-sha256-modp1536,aes256-sha256-modp2048,aes256-sha256-modp4096,aes256-sha384-ecp384,aes256-sha384-modp1024,aes256-sha384-modp1536,aes256-sha384-modp2048,aes256-sha384-modp4096,aes256gcm16-aes256gcm12-aes128gcm16-aes128gcm12-sha256-sha1-modp2048-modp4096-modp1024,3des-sha1-modp1024!
    esp=aes128-aes256-sha1-sha256-modp2048-modp4096-modp1024,aes128-sha1,aes128-sha1-modp1024,aes128-sha1-modp1536,aes128-sha1-modp2048,aes128-sha256,aes128-sha256-ecp256,aes128-sha256-modp1024,aes128-sha256-modp1536,aes128-sha256-modp2048,aes128gcm12-aes128gcm16-aes256gcm12-aes256gcm16-modp2048-modp4096-modp1024,aes128gcm16,aes128gcm16-ecp256,aes256-sha1,aes256-sha256,aes256-sha256-modp1024,aes256-sha256-modp1536,aes256-sha256-modp2048,aes256-sha256-modp4096,aes256-sha384,aes256-sha384-ecp384,aes256-sha384-modp1024,aes256-sha384-modp1536,aes256-sha384-modp2048,aes256-sha384-modp4096,aes256gcm16,aes256gcm16-ecp384,3des-sha1!
    fragmentation=yes
    forceencaps=yes
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftid=@$LEFT_ID
    leftcert=fullchain.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    leftfirewall=yes
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=10.15.1.0/24
    rightdns=1.1.1.1,8.8.8.8
    rightsendcert=never
    eap_identity=%identity
EOF
fi

if [ ! -f "/usr/local/etc/ipsec.secrets" ]; then
cat > /usr/local/etc/ipsec.secrets <<EOF
: RSA privkey.pem
EOF
fi
sysctl -p

ipsec start --nofork
