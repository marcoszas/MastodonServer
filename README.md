# Automatized Mastodon Server Installation

This project aims to streamline the process of installing and maintaining a Mastodon server using Docker and Ansible.

## Requirements

First of all you'll need to have a control node from where Ansible instructions will run and a host where the Mastodon server itself will be installed.

The **control node** will have to be **Red Hat, Debian, CentOS, macOS, any of the BSDs, and so on**, as stated in the official Ansible documentation. Windows is not supported as the control node.

The **host** will have to be a **Ubuntu Server 22.04** that allows for SSH connections.

Several dependencies will have to be installed in the control node:
- Ansible 2.16.5
- Python 2 (version 2.6 or later) or Python 3 (version 3.5 or later)
- Pip
- Ansible Galaxy collections
    - ansible.posix

For further information on Ansible requirements and dependencies you can check [Ansible Requirements](https://docs.ansible.com/ansible/2.9/installation_guide/index.html).

The necessary dependencies for the host machine are listed below (although they'll be automatically installed by the Ansible script):
- Docker
- Docker-compose
- Firewalld
- Nginx

## Installing / Getting started

First, install the dependencies.

You can check whether you already have python installed by executing
```shell
python3 --version
```
If it returns something like:
```shell
Python 3.12
```
Python is already installed in you control node.

Otherwise refer to the official [Python installation guide](https://wiki.python.org/moin/BeginnersGuide/Download).

To install Ansible you can check the official [Ansible installation guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#selecting-an-ansible-package-and-version-to-install).

Then clone the project via SSH or HTTPS, whatever is preferred.

> Ansible can be installed in a Python virtual environment as well. To do so refer the the [official Ansible documentation](https://docs.ansible.com/ansible/2.9/installation_guide/intro_installation.html#installing-ansible-with-pip).

### Initial Configuration

To start with the installation of the Mastodon Server, a few configurations need to be done first.
Ansible executes the tasks trough an SSH connection, so the host machine will have to have the control node added as a trusted connection.

##### 1. Generate an SSH key
Run the following command and go through the configuration.
```shell
ssh-keygen
```
Further info about this can be explored in [SSH documentation](https://www.ssh.com/academy/ssh/keygen#creating-an-ssh-key-pair-for-user-authentication).

The resulting keys will be stored in the .ssh folder in your home directory.

##### 2. Copy the newly generated public key in the host machine

The easiest way to do so, is by connecting the control node with the host machine via SSH
```shell
ssh username@host_ip
```
substituting the **username** and **host_ip** with the corresponding values.

Then modify the "./authorized_keys" or "./known_hosts" file in the ".ssh" directory with vim (or your preferred text editor)
```shell
vim ~/.ssh/authorized_keys
```
by pasting the contents of the public key (.pub file) generated earlier.

Now Ansible should be able to connect to the target host machine and execute the necessary tasks for the Mastodon server installation.

##### 3. Install the necessary ansible-galaxy collections

- To install **ansible.posix** run
    ```shell
    ansible-galaxy collection install ansible.posix
    ```
    If the control node is a MacOS machine it may run into a certificates problem, it can be avoided by using the "--ignore-certs" flag like so
    ```shell
    ansible-galaxy collection install ansible.posix --ignore-certs
    ```

##### 4. Configure the Ansible inventory file with the target host connection information
1. Open the inventory.ini file located in the repository directory.
2. Set the **ansible_host** and the **ansible_user** to the corresponding **ip** and **user** values from the target host machine, it should look something like ```mastodon ansible_host=192.168.0.0 ansible_user=foobar```.
3. Save the changes.

### Executing the Ansible playbook

Now it should be possible to run the ```ansible-playbook``` command to install **Mastodon** in the target host machine.

1. Open a terminal in your control node.
2. ```cd``` into the repository location in your system.
3. Execute the Ansible playbook by running the following command
```shell
ansible-playbook -i inventory.ini --ask-become-pass mastodon_install.ansible.yml
```
4. Wait for the tasks to finish.
5. Finally, a Mastodon server instance should be running in a Docker container within the target host.

## Features

- Install Mastodon server dependencies automatically.
- Automatically configure the host machine minimizing the room for error.
- Perform initial server configuration automatically.
- Update dependencies versions.

## Configuration

The configuration of the installation script, is done trough the "main.yml" file, located in the "roles/mastodon/vars/" directory, located inside the project.

The initial configuration must be set like this
```yaml
mastodon_server_hostname: mastodon
mastodon_install_dependencies: true
mastodon_perform_initial_config: true
mastodon_generate_secrets: true
```

## Contributing

If you wish to contribute to the project, please fork the repository and use a feature branch. Pull requests will be reviewed as fast as possible.

## Licensing

The code in this project is licensed under Apache-2.0 license.
