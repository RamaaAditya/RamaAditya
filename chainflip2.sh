#!/bin/bash

# Fungsi untuk menampilkan progress bar
show_progress() {
    local total_steps=$1
    local current_step=0
    
    while [ $current_step -le $total_steps ]; do
        echo -ne "Processing: ${current_step}%\r"
        sleep 0.5
        ((current_step+=5))
    done
    echo -ne "Installation complete: 100%\n"
}

echo -p "
░█████╗░██╗░░██╗░█████╗░██╗███╗░░██╗███████╗██╗░░░░░██╗██████╗░
██╔══██╗██║░░██║██╔══██╗██║████╗░██║██╔════╝██║░░░░░██║██╔══██╗
██║░░╚═╝███████║███████║██║██╔██╗██║█████╗░░██║░░░░░██║██████╔╝
██║░░██╗██╔══██║██╔══██║██║██║╚████║██╔══╝░░██║░░░░░██║██╝░
╚█████╔╝██║░░██║██║░░██║██║██║░╚███║██║░░░░░███████╗██║██║░░░░░
░╚════╝░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝╚═╝░░╚══╝╚═╝░░░░░╚═══  @RamaAditya"

echo "Pilih opsi yang ingin Anda jalankan:"
echo "1. Install Dependencies"
echo "2. Auto Sync Installation"
echo "3. Remove Previous Installation "
echo "4. Start the node and engine"
echo "5. Upgrade the node ( Without Update the keyrings version )"
read -p "Your choice: " choice

case $choice in
  1)
    # Step 1: Install System
    read -p -c "Input IP Address: " ip_address
    read -p "Input WSS endpoint: " wss_endpoint
    read -p "Input HTTPS endpoint: " https_endpoint
    read -p "Input Private Key from Metamask: " private_key
    read -p "Input Secret Seed: " secret_seed


    {
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL repo.chainflip.io/keys/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/chainflip.gpg
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/chainflip.gpg] https://repo.chainflip.io/perseverance/$(lsb_release -c -s) $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/chainflip.list > /dev/null
        sudo apt-get update -qq > /dev/null 2>&1
        sudo apt-get install -y chainflip-cli chainflip-node chainflip-engine > /dev/null 2>&1
        sudo mkdir -p /etc/chainflip/keys
    } & show_progress 50


# Step 2: Add Private Key
echo -n "$private_key" | sudo tee /etc/chainflip/keys/ethereum_key_file > /dev/null

# Step 3: Add Secret Seed
echo -n "${secret_seed:2}" | sudo tee /etc/chainflip/keys/signing_key_file > /dev/null
sudo chainflip-node key generate-node-key --file /etc/chainflip/keys/node_key_file > /dev/null

# Step 4: Configuration Settings.toml
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
} & show_progress 100

echo "Installations Were Already done!"
    ;;
    
  
  2)
    echo "Menjalankan Auto Sync Installation..."
    {
        sudo systemctl stop chainflip-node && sudo systemctl stop chainflip-engine
        sudo rm -rf /lib/systemd/system/chainflip-node.service
        sudo rm -rf /etc/systemd/system/chainflip-node.service.d/override.conf
        sudo rm -rf /etc/chainflip/chaindata

        cat <<EOF | sudo tee /lib/systemd/system/chainflip-node.service > /dev/null
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

        cat <<EOF | sudo tee /etc/systemd/system/chainflip-node.service.d/override.conf > /dev/null
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
    } & show_progress 100

    echo "Auto Sync Installation selesai."
    ;;

  3)
     echo "Check previous version..."
     {
        sudo systemctl stop chainflip-node && sudo systemctl stop chainflip-engine
        sudo rm -rf /etc/apt/keyrings/
        sudo rm -rf /etc/chainflip/
     } & show_progress 100
     
    echo "All were done."
       ;;

4) 
     echo "Start the engine ..."
     {  
        sudo systemctl start chainflip-node && sudo systemctl start chainflip-engine
        sudo systemctl enable chainflip-node && sudo systemctl enable chainflip-engine
        systemctl restart chainflip-engine
     } & show_progress 100
    ;;


  *)
    echo "Pilihan tidak valid."
    ;;
esac
