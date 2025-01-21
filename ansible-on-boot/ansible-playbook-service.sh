#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <secure_password>"
    exit 1
fi

SECURE_PASSWORD=$1
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
LOG_FILE="/var/log/ansible-playbook-setup-$TIMESTAMP.log"
VAULT_FILE="/home/mkadmin/ansible/vars/mkadmin.yml"
SERVICE_FILE="/etc/systemd/system/ansible-playbook.service"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "Log file: $LOG_FILE"

log "Updating package list..."
sudo apt-get update &>> $LOG_FILE

log "Installing Ansible..."
sudo apt-get install -y ansible &>> $LOG_FILE

log "Creating Ansible Vault file directory..."
sudo mkdir -p /home/mkadmin/ansible/vars &>> $LOG_FILE
sudo chown -R mkadmin:mkadmin /home/mkadmin/ansible &>> $LOG_FILE

if [ -f "$VAULT_FILE" ]; then
    log "Ansible Vault file already exists. Checking if it is encrypted..."
    
    if sudo -u mkadmin ansible-vault view $VAULT_FILE &> /dev/null; then
        log "Ansible Vault file is already encrypted. Skipping creation."
    else
        log "Ansible Vault file exists but is not encrypted. Please encrypt the file manually."
        exit 1
    fi
else
    log "Creating Ansible Vault file with initial content..."
    sudo bash -c "cat <<EOF > $VAULT_FILE
mkadmin_password: \"$SECURE_PASSWORD\"
EOF"
    sudo chown mkadmin:mkadmin $VAULT_FILE

    log "Encrypting the Ansible Vault file..."
    sudo -u mkadmin ansible-vault encrypt $VAULT_FILE &>> $LOG_FILE
fi

log "Creating or overwriting systemd service file..."
sudo bash -c 'cat <<EOF > /etc/systemd/system/ansible-playbook.service
[Unit]
Description=Run Ansible Playbook at boot
After=network.target

[Service]
ExecStart=/bin/bash -c "ansible-playbook /home/mkadmin/ansible/docker-install.yml --ask-vault-pass"
Type=oneshot
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF' &>> $LOG_FILE

log "Reloading systemd..."
sudo systemctl daemon-reload &>> $LOG_FILE

log "Enabling Ansible service to run at boot..."
sudo systemctl enable ansible-playbook.service &>> $LOG_FILE

log "Starting Ansible service manually..."
sudo systemctl start ansible-playbook.service &>> $LOG_FILE

log "Checking the status of the Ansible service..."
sudo systemctl status ansible-playbook.service &>> $LOG_FILE
