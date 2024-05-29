# Automatized Mastodon Server Installation

This project aims to streamline the process of installing and maintaining a Mastodon server using Ansible.

## Requirements

First of all you'll need to have a control node from where Ansible instructions will run and a host where the Mastodon server itself will be installed.

The **control node** will have to be **Red Hat, Debian, CentOS, macOS, any of the BSDs, and so on**, as stated in the official Ansible documentation. Windows is not supported as the control node.

The **host** will have to be an **Ubuntu Server 20.04** that allows for SSH connections.

Several dependencies will have to be installed in the control node:
- Ansible or Ansible Core >=2.16.5
- Python 2 (version 2.6 or later) or Python 3 (version 3.5 or later)
- Pip
- Ansible Galaxy collections
    - community.general

For further information on Ansible requirements and dependencies you can check [Ansible Requirements](https://docs.ansible.com/ansible/2.9/installation_guide/index.html).

Some of the necessary dependencies for the host machine are listed below (although they'll be automatically installed by the Ansible script):
- Iptables
- Redis
- PostgreSQL
- Nginx
- Elasticsearch

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

- To install the required collections run
    ```shell
    ansible-galaxy install -r requirements.yml
    ```

If the control node is a MacOS machine it may run into a certificates problem, it can be avoided by using the "--ignore-certs" flag like so
```shell
ansible-galaxy install -r requirements.yml --ignore-certs
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
4. Enter the target's host password.
5. Wait for the tasks to finish.
6. Finally, a Mastodon server instance should be running within the target host.

## Features

- Install Mastodon server dependencies automatically.
- Automatically configure the host machine minimizing the room for error.
- Perform initial server configuration automatically.
- Update dependencies versions.
- Set automatic maintenance tasks.

## Configuration

The configuration of the installation script, is done trough the "main.yml" file, located in the "roles/mastodon/vars/" directory, located inside the project.

These values must be substituted with valid ones, or they can be left unchanged if you're just trying the installation.
```yaml
---
# Server configuration
mastodon_server_domain: example.com
mastodon_personal_email: example@email.com
mastodon_smtp_from_address: 'Mastodon <notifications@test.example.com>'

# Passwords
mastodon_postgresql_password: foobar
mastodon_redis_password: foobar

# Admin account
mastodon_admin_account_name: admin
mastodon_admin_email: admin@email.com

```

### Updating dependencies

The versions of the dependencies for the Mastodon server can be updated or downgraded by setting the desired versions in the "main.yml" file located in /roles/dependencies/vars/main.yml.
```yaml
---
# Versions
dependencies_mastodon_version: v4.2.8
dependencies_postgresql_source_distro_version: focal-pgdg
dependencies_postgresql_source_tag: main
dependencies_postgresql_version: 16+260.pgdg20.04+1
dependencies_nodejs_distro_version: nodistro
dependencies_nodejs_source_tag: main
dependencies_nodejs_version: 20.13.1-1nodesource1
dependencies_redis_version: 5:5.0.7-2ubuntu0.1
dependencies_elasticsearch_version: 7.17.21
dependencies_nginx_version: 1.18.0-0ubuntu1.4
dependencies_rbenv_version: v1.2.0
dependencies_rbenv_build_version: v20240517
dependencies_ruby_version: 3.2.3
dependencies_python3_version: 3.8.2-0ubuntu2
```

In order to apply the configuration, you need to launch the maintenance playbook with the following command:

```shell
ansible-playbook -i inventory.ini --ask-become-pass mastodon_maintenance.ansible.yml
```

The maintenance playbook can also apply some other automations to keep the Mastodon server in shape.

The configuration of the playbook can be done through the "main.yml" file located in /roles/mastodon-maintenance/vars/main.yml.
```yaml
---
mastodon_maintenance_update_versions: true
mastodon_maintenance_restart_mastodon: true
mastodon_maintenance_apply_basic_maintenance: false
```

If the automatic maintenance tasks are to be activated, the "mastodon_maintenance_apply_basic_maintenance" variable, must be set to true. The configuration can be deactivated by setting the variable to false and running the maintenance playbook again.

## Contributing

If you wish to contribute to the project, please fork the repository and use a feature branch. Pull requests will be reviewed as fast as possible.
The [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) standard is recommended when uploading commits to the repository.

## Licensing

The code in this project is licensed under Apache-2.0 license.
