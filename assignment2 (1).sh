#!/bin/bash

log_error() {
    local err_msg="Error: $1"
    echo "$err_msg" >&2
}

configure_net_interface() {
    local netplan_cfg="/etc/netplan/01-netcfg.yaml"
    sudo tee "$netplan_cfg" > /dev/null <<EOF
network:
  version: 2
  ethernets:
    ens3:
      addresses:
        - 192.168.16.21/24
      gateway4: 192.168.16.2
      nameservers:
        addresses: [192.168.16.2]
        search: [home.arpa, localdomain]
EOF
    sudo netplan apply || { log_error "Failed to apply netplan config"; exit 1; }
}

update_hosts() {
    local hosts_file="/etc/hosts"
    sudo sed -i '/server1/d' "$hosts_file"
    echo "192.168.16.21    server1" | sudo tee -a "$hosts_file" > /dev/null
}

install_pkgs() {
    local pkgs=("apache2" "squid")
    sudo apt update || { log_error "Failed to update package list"; exit 1; }
    sudo apt install -y "${pkgs[@]}" || { log_error "Failed to install packages"; exit 1; }
}

configure_fw() {
    local fw_rules=(
        "sudo ufw allow in on ens4 from 192.168.16.0/24 to any port 22"
        "sudo ufw allow in on ens3 to any port 80"
        "sudo ufw allow in on ens4 to any port 80"
        "sudo ufw allow in on ens3 to any port 3128"
        "sudo ufw allow in on ens4 to any port 3128"
        "sudo ufw --force enable"
    )
    for rule in "${fw_rules[@]}"; do
        eval "$rule" || { log_error "Failed to execute firewall rule: $rule"; exit 1; }
    done
}

configure_users() {
    local users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")
    local ssh_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"
    for user in "${users[@]}"; do
        local user_home="/home/$user"
        sudo useradd -m -s /bin/bash "$user" || { log_error "Failed to create user '$user'"; exit 1; }
        sudo mkdir -p "$user_home/.ssh" || { log_error "Failed to create .ssh directory for '$user'"; exit 1; }
        sudo chmod 700 "$user_home/.ssh" || { log_error "Failed to set permissions for .ssh directory of '$user'"; exit 1; }
        sudo touch "$user_home/.ssh/authorized_keys" || { log_error "Failed to create authorized_keys for '$user'"; exit 1; }
        sudo chmod 600 "$user_home/.ssh/authorized_keys" || { log_error "Failed to set permissions for authorized_keys of '$user'"; exit 1; }
        sudo bash -c "echo '$ssh_key' >> $user_home/.ssh/authorized_keys" || { log_error "Failed to add SSH keys for '$user'"; exit 1; }
    done
}

main() {
    configure_net_interface
    update_hosts
    install_pkgs
    configure_fw
    configure_users
}

main
