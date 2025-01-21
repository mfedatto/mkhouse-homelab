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
BACKUP_SERVICE_FILE="/etc/systemd/system/ansible-playbook.service.bak.$TIMESTAMP"

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

# Verificar se o arquivo vault_password.txt está vazio
if [ ! -s $VAULT_PASSWORD_FILE ]; then
    log "Vault password file is empty. Regenerating password..."
    VAULT_PASSWORD=$(generate_password)
    echo "$VAULT_PASSWORD" | sudo tee $VAULT_PASSWORD_FILE &>> $LOG_FILE
    sudo chmod 600 $VAULT_PASSWORD_FILE
    sudo chown mkadmin:mkadmin $VAULT_PASSWORD_FILE
fi

log "Creating Ansible Vault file with provided mkadmin password..."
sudo bash -c "cat <<EOF > $VAULT_FILE
mkadmin_password: \"$MKADMIN_PASSWORD\"
EOF"
sudo chown mkadmin:mkadmin $VAULT_FILE

log "Encrypting the Ansible Vault file..."
sudo -u mkadmin ansible-vault encrypt --vault-password-file $VAULT_PASSWORD_FILE $VAULT_FILE &>> $LOG_FILE

if systemctl list-units --full -all | grep -Fq "ansible-playbook.service"; then
    log "Service file exists. Backing up and removing existing service..."
    sudo cp $SERVICE_FILE $BACKUP_SERVICE_FILE &>> $LOG_FILE
    sudo systemctl stop ansible-playbook.service &>> $LOG_FILE
    sudo systemctl disable ansible-playbook.service &>> $LOG_FILE
    sudo rm -f $SERVICE_FILE &>> $LOG_FILE
    sudo systemctl daemon-reload &>> $LOG_FILE
    sudo systemctl reset-failed ansible-playbook.service &>> $LOG_FILE
    
    log "Checking for residual symlinks..."
    SYMLINKS=$(find /etc/systemd/system -type l -name "ansible-playbook.service")
    if [ -n "$SYMLINKS" ]; then
        log "Removing residual symlinks..."
        echo "$SYMLINKS" | xargs sudo rm -f &>> $LOG_FILE
    fi
fi

log "Creating new systemd service file..."
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
if sudo systemctl start ansible-playbook.service &>> $LOG_FILE; then
    log "Service started successfully. Removing backup service file..."
    sudo rm -f $BACKUP_SERVICE_FILE &>> $LOG_FILE
else
    log "Service failed to start. Restoring backup service file..."
    sudo mv $BACKUP_SERVICE_FILE $SERVICE_FILE &>> $LOG_FILE
    sudo systemctl daemon-reload &>> $LOG_FILE
    sudo systemctl enable ansible-playbook.service &>> $LOG_FILE
    sudo systemctl start ansible-playbook.service &>> $LOG_FILE
fi

log "Checking the status of the Ansible service..."
sudo systemctl status ansible-playbook.service &>> $LOG_FILE
