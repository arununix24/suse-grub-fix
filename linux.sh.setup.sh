#!/bin/bash
set -e

echo "=================================================="
echo " SLES 15 SP7 SoftEther Setup Script (Fixed)"
echo "=================================================="

# Detect OS
. /etc/os-release

if [[ "$ID" != "sles" ]]; then
    echo "This script supports only SLES."
    exit 1
fi

echo "Running on: $PRETTY_NAME"
echo "Kernel: $(uname -r)"

############################################
# Install Required Packages (SLES way)
############################################

echo "Installing required packages..."

zypper --non-interactive install -y \
    bc \
    gcc \
    make \
    tar \
    wget \
    net-tools \
    fail2ban \
    openvpn

############################################
# Enable and Start Fail2Ban
############################################

echo "Configuring Fail2Ban..."

systemctl enable fail2ban
systemctl restart fail2ban

############################################
# Setup vpnclient service
############################################

echo "Setting up vpnclient service..."

if [ ! -f /etc/systemd/system/vpnclient.service ]; then
    cp vpnclient.service /etc/systemd/system/
    chmod 644 /etc/systemd/system/vpnclient.service
    systemctl daemon-reload
    systemctl enable vpnclient.service
fi

############################################
# Fix MacAddress in config
############################################

if [ -f /usr/bin/vpnclient/vpn_client.config ]; then
    NEWMAC=$(printf '00:AC:26:%02X:%02X:%02X\n' \
        $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))

    sed -i "s/^.*MacAddress.*$/string MacAddress $NEWMAC/" \
        /usr/bin/vpnclient/vpn_client.config

    echo "New MAC set: $NEWMAC"
fi

############################################
# Start VPN Client
############################################

echo "Starting vpnclient..."
systemctl restart vpnclient

echo "=================================================="
echo " Setup Completed Successfully"
echo "=================================================="