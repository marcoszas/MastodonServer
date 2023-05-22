#!/bin/bash

sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible

ansible --version

# ansible-playbook mastodon_install.ansible.yml

# SO the idea with this would be to use this script to jumpstart all the process without
# the user having to do much. So we would install Ansible automatically and then
# the idea is to check if it's been installed correctly and after doing so, we just
# execute the Ansible playbook that at the same time is going to use all the necessary
# files that we'll be providing in the code repository.