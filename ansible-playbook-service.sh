#!/bin/bash

TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
LOG_FILE="/var/log/ansible-playbook-setup-$TIMESTAMP.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

log "Log file: $LOG_FILE"

log "Updating package list..."
sudo apt-get update &>> $LOG_FILE

log "Installing Ansible..."
sudo apt-get install -y ansible &>> $LOG_FILE

log "Creating systemd service file..."
sudo bash -c 'cat <<EOF > /etc/systemd/system/ansible-playbook.service
[Unit]
Description=Run Ansible Playbook at boot
After=network.target

[Service]
ExecStart=/bin/bash -c "curl -sL https://raw.githubusercontent.com/mfedatto/mkhouse-homelab/refs/heads/master/ansible-playbook.yaml -o /tmp/ansible-playbook.yaml && ansible-playbook /tmp/ansible-playbook.yaml"
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
