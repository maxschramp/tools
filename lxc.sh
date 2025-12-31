#!/bin/bash

apt update
apt install curl -y

curl -fsSL https://get.docker.com | sh
curl -fsSL https://tailscale.com/install.sh | sh
