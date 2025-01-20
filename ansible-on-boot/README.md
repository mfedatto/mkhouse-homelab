# Ansible Playbook on boot Service Setup Script

This script automates the setup of a systemd service that downloads and runs an Ansible playbook from a remote repository at system boot. 

## Features

- Updates the package list
- Installs Ansible
- Creates a systemd service file to download and run the Ansible playbook
- Enables the service to run at boot
- Logs all operations to a timestamped log file

## Prerequisites

- A Unix-based operating system with systemd (e.g., Ubuntu)
- curl installed on your system
- sudo privileges

## Installation

1. Download the script:

``` bash
curl -O https://raw.githubusercontent.com/mfedatto/mkhouse-homelab/refs/heads/master/ansible-on-boot/ansible-playbook-service.sh
```

2. Make the script executable:

``` bash
chmod +x ansible-playbook-service.sh
```

3. Run the script:

``` bash
sudo ./ansible-playbook-service.sh
```

## How It Works

1. **Update Package List:** The script updates the package list to ensure the latest versions of packages are available.
2. **Install Ansible:** The script installs Ansible if it is not already installed.
3. **Create systemd Service:** The script creates a systemd service file that:
    - Downloads the Ansible playbook from the specified URL.
    - Runs the downloaded playbook.
4. **Enable and Start the Service:** The service is enabled to run at boot and is started immediately to verify functionality.
5. **Logging:** All operations are logged to a file located in `/var/log` with a timestamped filename.

## Log File

The script logs its operations to a file located at `/var/log/ansible-playbook-setup-<TIMESTAMP>.log`. Replace `<TIMESTAMP>` with the actual timestamp of the script execution.

## Service Details

The created systemd service file is located at `/etc/systemd/system/ansible-playbook.service` and contains the following configuration:

``` ini
[Unit]
Description=Run Ansible Playbook at boot
After=network.target

[Service]
ExecStart=/bin/bash -c "curl -sL https://raw.githubusercontent.com/mfedatto/mkhouse-homelab/refs/heads/master/ansible-on-boot/ansible-playbook.yaml -o /tmp/ansible-playbook.yaml && ansible-playbook /tmp/ansible-playbook.yaml"
Type=oneshot
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
```

## Checking the Status of the Service

To check the status of the `ansible-playbook` service, use the following command:

``` bash
sudo systemctl status ansible-playbook.service
```

## Troubleshooting

- Ensure you have sudo privileges.
- Verify that `curl` is installed.
- Check the log file in `/var/log` for any errors.