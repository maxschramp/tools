#!/bin/sh

set -e

DEPLOY_USER=deploy
SSH_PORT=22
SSHD_CONFIG=/etc/ssh/sshd_config

echo "== Updating system =="
apt update && apt upgrade -y

echo "== Installing security packages =="
apt install -y sudo ufw fail2ban unattended-upgrades

echo "== Creating deploy user =="
if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
    adduser --gecos "" "$DEPLOY_USER"
fi

echo "== Adding deploy to sudo group =="
usermod -aG sudo "$DEPLOY_USER"

echo "== Setting up SSH directory for deploy =="
HOME_DIR="/home/$DEPLOY_USER"
SSH_DIR="$HOME_DIR/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$SSH_DIR"

echo "IMPORTANT:"
echo "Add your SSH public key to:"
echo "$AUTH_KEYS"
echo "Press ENTER to continue."
read _
nano /home/deploy/.ssh/authorized_keys

echo "== Hardening SSH configuration =="
cp "$SSHD_CONFIG" "$SSHD_CONFIG.bak"

sed -i "s/^#\?Port .*/Port $SSH_PORT/" "$SSHD_CONFIG"
sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin no/" "$SSHD_CONFIG"
sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication no/" "$SSHD_CONFIG"
sed -i "s/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/" "$SSHD_CONFIG"
sed -i "s/^#\?X11Forwarding .*/X11Forwarding no/" "$SSHD_CONFIG"
sed -i "s/^#\?MaxAuthTries .*/MaxAuthTries 3/" "$SSHD_CONFIG"
sed -i "s/^#\?LoginGraceTime .*/LoginGraceTime 30/" "$SSHD_CONFIG"

if grep -q "^AllowUsers" "$SSHD_CONFIG"; then
    sed -i "s/^AllowUsers.*/AllowUsers $DEPLOY_USER/" "$SSHD_CONFIG"
else
    echo "AllowUsers $DEPLOY_USER" >>"$SSHD_CONFIG"
fi

systemctl restart ssh

echo "== Configuring UFW firewall =="
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSH_PORT/tcp"
ufw --force enable

echo "== Configuring Fail2Ban =="
cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1h
EOF

systemctl restart fail2ban

echo "== Enabling unattended upgrades =="
dpkg-reconfigure -f noninteractive unattended-upgrades
systemctl enable unattended-upgrades
systemctl start unattended-upgrades

echo "== Locking root account =="
passwd -l root

echo "== Hardening complete =="
echo "Verify access with:"
echo "ssh $DEPLOY_USER@your_server_ip"
echo "Do NOT close this session until confirmed."
