#!/bin/bash

for i in {1..254}; do
	timeout 1 bash -c "ping -c 1 192.168.1.$i" > /dev/null 2>&1 && echo "host 192.168.1.$i connected" &
done

