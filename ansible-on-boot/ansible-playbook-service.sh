#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <mkadmin_password>"
    exit 1
fi

MKADMIN_PASSWORD=$1

# Função para gerar uma senha aleatória
generate_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*()_+{}[]|:;<>,.?/~`-=' </dev/urandom | head -c 16
}

VAULT_PASSWORD=$(generate_password)
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
LOG_FILE="/var/log/ansible-playbook-setup-$TIMESTAMP.log"
PLAYBOOK_URL="https://raw.githubusercontent.com/mfedatto/mkhouse-homelab/refs/heads/master/ansible-on-boot/boot-setup.yml"
PLAYBOOK_PATH="/home/mkadmin/ansible/boot-setup.yml"
VAULT_FILE="/home/mkadmin/ansible/vars/mkadmin.yml"
VAULT_PASSWORD_FILE="/home/mkadmin/ansible/vault_password.txt"
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

log "Downloading the playbook..."
sudo wget -O $PLAYBOOK_PATH $PLAYBOOK_URL &>> $LOG_FILE
sudo chown mkadmin:mkadmin $PLAYBOOK_PATH

log "Generating vault password and storing it securely..."
echo "$VAULT_PASSWORD" | sudo tee $VAULT_PASSWORD_FILE &>> $LOG_FILE
sudo chmod 600 $VAULT_PASSWORD_FILE
sudo chown mkadmin:mkadmin $VAULT_PASSWORD_FILE

log "Creating Ansible Vault file with provided mkadmin password..."
sudo bash -c "cat <<EOF > $VAULT_FILE
mkadmin_password: \"$MKADMIN_PASSWORD\"
EOF"
sudo chown mkadmin:mkadmin $VAULT_FILE

log "Encrypting the Ansible Vault file..."
sudo -u mkadmin ansible-vault encrypt --vault-password-file $VAULT_PASSWORD_FILE $VAULT_FILE &>> $LOG_FILE

log "Creating or overwriting systemd service file..."
sudo bash -c 'cat <<EOF > /etc/systemd/system/ansible-playbook.service
[Unit]
Description=Run Ansible Playbook at boot
After=network.target

[Service]
ExecStart=/bin/bash -c "ansible-playbook /home/mkadmin/ansible/boot-setup.yml --vault-password-file /home/mkadmin/ansible/vault_password.txt"
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
