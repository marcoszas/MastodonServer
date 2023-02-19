#!/bin/bash

# Update and upgrade packages
sudo apt update
sudo apt upgrade

# Get the name of the network interface 
network_interface=$(ip -br a | sed -n '2p' | cut -d ' ' -f 1)

# Install the firewall
sudo apt install firewalld


# Add external interfaces to the public zone 
sudo firewall-cmd --add-interface $network_interface --zone public


# Ensure that docker interface is in a trusted zone 
sudo firewall-cmd --add-interface=docker0 --zone trusted

# Add masquerade 
sudo firewall-cmd --zone=public --add-masquerade
