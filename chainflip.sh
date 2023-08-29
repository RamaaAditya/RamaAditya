#!/bin/bash

# Fungsi untuk menampilkan spinner
#!/bin/bash

# Fungsi untuk menampilkan spinner
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

echo "Pilih opsi yang ingin Anda jalankan:"
echo "1. Install System"
echo "2. Auto Sync Installation"
read -p "Pilihan Anda: " choice

case $choice in
  1)
    spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Step 1: Install System
# Input IP, WSS, HTTPS
read -p "Masukkan IP Address: " ip_address
read -p "Masukkan WSS endpoint: " wss_endpoint
read -p "Masukkan HTTPS endpoint: " https_endpoint

echo "Menginstal sistem..."
{
    sudo rm -rf /etc/apt/keyrings/
    sudo rm -rf /etc/chainflip/
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL repo.chainflip.io/keys/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/chainflip.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/chainflip.gpg] https://repo.chainflip.io/perseverance/$(lsb_release -c -s) $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/chainflip.list > /dev/null
    sudo apt update > /dev/null
    sudo apt install -y chainflip-cli chainflip-node chainflip-engine > /dev/null
    sudo mkdir /etc/chainflip/keys
} & spinner

# Step 2: Input Private Key
read -p "Masukkan Private Key dari Metamask: " private_key
echo -n "$private_key" | sudo tee /etc/chainflip/keys/ethereum_key_file > /dev/null

# Step 3: Input Secret Seed
read -p "Masukkan Secret Seed: " secret_seed
echo -n "${secret_seed:2}" | sudo tee /etc/chainflip/keys/signing_key_file > /dev/null
sudo chainflip-node key generate-node-key --file /etc/chainflip/keys/node_key_file > /dev/null

# Step 4: Konfigurasi Settings.toml
echo "Menyiapkan konfigurasi..."
{
    sudo mkdir -p /etc/chainflip/config

    cat <<EOL | sudo tee /etc/chainflip/config/Settings.toml > /dev/null
# Default configurations for the CFE
[node_p2p]
node_key_file = "/etc/chainflip/keys/node_key_file"
ip_address = "$ip_address"
port = "8078"

[state_chain]
ws_endpoint = "ws://127.0.0.1:9944"
signing_key_file = "/etc/chainflip/keys/signing_key_file"

[eth]
# Ethereum RPC endpoints (websocket and http for redundancy).
ws_node_endpoint = "$wss_endpoint"
http_node_endpoint = "$https_endpoint"

# Ethereum private key file path. This file should contain a hex-encoded private key.
private_key_file = "/etc/chainflip/keys/ethereum_key_file"

[signing]
db_file = "/etc/chainflip/data.db"

[dot]
ws_node_endpoint = "wss://pdot.chainflip.xyz:443"

[btc]
http_node_endpoint = "http://a108a82b574a640359e360cf66afd45d-424380952.eu-central-1.elb.amazonaws.com"
rpc_user = "flip"
rpc_password = "flip"
EOL
} & spinner

echo "Installations Were Already done!"
    ;;
  
  2)
    echo "Menjalankan Auto Sync Installation..."
    {
        sudo systemctl stop chainflip-node && sudo systemctl stop chainflip-engine
        rm -rf /lib/systemd/system/chainflip-node.service
        rm -rf /etc/systemd/system/chainflip-node.service.d/override.conf
        rm -rf /etc/chainflip/chaindata

        cat <<EOF | sudo tee /lib/systemd/system/chainflip-node.service >/dev/null
[Unit]
Description=Chainflip Validator Node

[Service]
Restart=always
RestartSec=30
Type=simple

ExecStart=/usr/bin/chainflip-node \
  --chain /etc/chainflip/perseverance.chainspec.json \
  --base-path /etc/chainflip/chaindata \
  --node-key-file /etc/chainflip/keys/node_key_file \
  --validator \
  --sync=warp \
  --state-cache-size 0

[Install]
WantedBy=multi-user.target
EOF

        cat <<EOF | sudo tee /etc/systemd/system/chainflip-node.service.d/override.conf >/dev/null
[Service]
ExecStart=
ExecStart=/usr/bin/chainflip-node \
  --chain /etc/chainflip/perseverance.chainspec.json \
  --base-path /etc/chainflip/chaindata \
  --node-key-file /etc/chainflip/keys/node_key_file \
  --validator \
  --prometheus-external \
  --sync=warp \
  --execution=native
EOF

        sudo systemctl daemon-reload
        sudo systemctl start chainflip-node && sudo systemctl start chainflip-engine
    } & spinner

    echo "Auto Sync Installation selesai."
    ;;
  
  *)
    echo "Pilihan tidak valid."
    ;;
esac

