#!/bin/bash

# Update and upgrade packages
sudo apt update
sudo apt upgrade

# Get the name of the network interface
network_interface=$(ip -br a | sed -n '2p' | cut -d ' ' -f 1)

# Install the firewall
sudo apt install firewalld


# Add external interfaces to the public zone
sudo firewall-cmd --add-interface "$network_interface" --zone public


# Ensure that docker interface is in a trusted zone
sudo firewall-cmd --add-interface=docker0 --zone trusted

# Add masquerade
sudo firewall-cmd --zone=public --add-masquerade

# Make changes permanent
sudo firewall-cmd --runtime-to-permanent

function confirm {
    read -r -p "$1 [Y/n] " response
    if [[ $response =~ ^(yes|y| ) || -z $response ]]; then
        true
    else
        false
    fi
}

# Save server hostname and make sure the user didn't make a mistake
server_hostname=''
while [[ ! "$server_hostname" ]]; do
    read -r -p "Enter the server hostname: " input_hostname
    if confirm "Are you sure you want to name your server hostname $input_hostname?"; then
        server_hostname="$input_hostname"
    fi
done

# Set server hostname
sudo hostnamectl --static set-hostname "$server_hostname"

# sysctl vm.max_map_count

echo "vm.max_map_count=262144" | sudo tee /etc/sysctl.d/90-max_map_count.conf

# check if necessary
sudo sysctl --system

sudo apt install docker.io docker-compose

sudo usermod -a -G docker "$USER"

cat <<EOF | sudo tee /etc/docker/daemon.json
{
    "iptables": false,
    "log-driver": "journald"
}
EOF

sudo reboot

# Need to execute a different script at this point