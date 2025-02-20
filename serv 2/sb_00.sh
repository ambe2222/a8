#!/bin/bash

re="\033[0m"
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
reading() { read -p "$(red "$1")" "$2"; }
export LC_ALL=C
HOSTNAME=$(hostname)
USERNAME=$(whoami | tr '[:upper:]' '[:lower:]')
export UUID=${UUID:-'bc97f674-c578-4940-9234-0a1da46041b0'}
export NEZHA_SERVER=${NEZHA_SERVER:-''} 
export NEZHA_PORT=${NEZHA_PORT:-'5555'}     
export NEZHA_KEY=${NEZHA_KEY:-''} 
export ARGO_DOMAIN=${ARGO_DOMAIN:-''}   
export ARGO_AUTH=${ARGO_AUTH:-''}
export VMESS_PORT=${VMESS_PORT:-''}
export TUIC_PORT=${TUIC_PORT:-''}
export HY2_PORT=${HY2_PORT:-''}
export CFIP=${CFIP:-'www.visa.com.tw'} 
export CFPORT=${CFPORT:-'443'} 
export SUB_TOKEN=${SUB_TOKEN:-'sub'}
[[ "$HOSTNAME" == "s1.ct8.pl" ]] && WORKDIR="${HOME}/domains/${USERNAME}.ct8.pl/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.ct8.pl/public_html" || WORKDIR="${HOME}/domains/${USERNAME}.serv00.net/logs" && FILE_PATH="${HOME}/domains/${USERNAME}.serv00.net/public_html"
rm -rf "$WORKDIR" && mkdir -p "$WORKDIR" "$FILE_PATH" && chmod 777 "$WORKDIR" "$FILE_PATH" >/dev/null 2>&1
bash -c 'ps aux | grep $(whoami) | grep -v "sshd\|bash\|grep" | awk "{print \$2}" | xargs -r kill -9 >/dev/null 2>&1' >/dev/null 2>&1

check_binexec_and_port () {
port_list=$(devil port list)
tcp_ports=$(echo "$port_list" | grep -c "tcp")
udp_ports=$(echo "$port_list" | grep -c "udp")

if [[ $tcp_ports -ne 1 || $udp_ports -ne 2 ]]; then
    red "The number of ports does not meet the requirements，Adjust..."

    if [[ $tcp_ports -gt 1 ]]; then
        tcp_to_delete=$((tcp_ports - 1))
        echo "$port_list" | awk '/tcp/ {print $1, $2}' | head -n $tcp_to_delete | while read port type; do
            devil port del $type $port
            green "DeletedTCPport: $port"
        done
    fi

    if [[ $udp_ports -gt 2 ]]; then
        udp_to_delete=$((udp_ports - 2))
        echo "$port_list" | awk '/udp/ {print $1, $2}' | head -n $udp_to_delete | while read port type; do
            devil port del $type $port
            green "DeletedUDPport: $port"
        done
    fi

    if [[ $tcp_ports -lt 1 ]]; then
        while true; do
            tcp_port=$(shuf -i 10000-65535 -n 1) 
            result=$(devil port add tcp $tcp_port 2>&1)
            if [[ $result == *"succesfully"* ]]; then
                green "Have been addedTCPport: $tcp_port"
                break
            else
                yellow "port $tcp_port Unavailable，尝试其他port..."
            fi
        done
    fi

    if [[ $udp_ports -lt 2 ]]; then
        udp_ports_to_add=$((2 - udp_ports))
        udp_ports_added=0
        while [[ $udp_ports_added -lt $udp_ports_to_add ]]; do
            udp_port=$(shuf -i 10000-65535 -n 1) 
            result=$(devil port add udp $udp_port 2>&1)
            if [[ $result == *"succesfully"* ]]; then
                green "Have been addedUDPport: $udp_port"
                if [[ $udp_ports_added -eq 0 ]]; then
                    udp_port1=$udp_port
                else
                    udp_port2=$udp_port
                fi
                udp_ports_added=$((udp_ports_added + 1))
            else
                yellow "port $udp_port Unavailable，尝试其他port..."
            fi
        done
    fi
    green "The port has been adjusted to complete,Will disconnectsshconnect,请重新connectshhRe -execute the script"
    devil binexec on >/dev/null 2>&1
    kill -9 $(ps -o ppid= -p $$) >/dev/null 2>&1
else
    tcp_port=$(echo "$port_list" | awk '/tcp/ {print $1}')
    udp_ports=$(echo "$port_list" | awk '/udp/ {print $1}')
    udp_port1=$(echo "$udp_ports" | sed -n '1p')
    udp_port2=$(echo "$udp_ports" | sed -n '2p')

    purple "currentTCPport: $tcp_port"
    purple "currentUDPport: $udp_port1 and $udp_port2"
fi

export VMESS_PORT=$tcp_port
export TUIC_PORT=$udp_port1
export HY2_PORT=$udp_port2
}

argo_configure() {
clear
purple "Under installation,Please wait..."
  if [[ -z $ARGO_AUTH || -z $ARGO_DOMAIN ]]; then
    green "ARGO_DOMAIN or ARGO_AUTH is empty,use quick tunnel"
    return
  fi

  if [[ $ARGO_AUTH =~ TunnelSecret ]]; then
    echo $ARGO_AUTH > tunnel.json
    cat > tunnel.yml << EOF
tunnel: $(cut -d\" -f12 <<< "$ARGO_AUTH")
credentials-file: tunnel.json
protocol: http2

ingress:
  - hostname: $ARGO_DOMAIN
    service: http://localhost:$VMESS_PORT
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
  else
    green "ARGO_AUTH mismatch TunnelSecret,use token connect to tunnel"
  fi
}

generate_config() {

    openssl ecparam -genkey -name prime256v1 -out "private.key"
    openssl req -new -x509 -days 3650 -key "private.key" -out "cert.pem" -subj "/CN=$USERNAME.serv00.net"

  yellow "AvailableIPmiddle,Please wait..."
  available_ip=$(get_ip)
  purple "Current choiceIPfor：$available_ip If the node is not available after the installation, you can try reinstallation"
  
cat > config.json << EOF
{
  "log": {
    "disabled": true,
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "address": "8.8.8.8",
        "address_resolver": "local"
      },
      {
        "tag": "local",
        "address": "local"
      }
    ]
  },
  "inbounds": [
    {
       "tag": "hysteria-in",
       "type": "hysteria2",
       "listen": "$available_ip",
       "listen_port": $HY2_PORT,
       "users": [
         {
             "password": "$UUID"
         }
     ],
     "masquerade": "https://bing.com",
     "tls": {
         "enabled": true,
         "alpn": [
             "h3"
         ],
         "certificate_path": "cert.pem",
         "key_path": "private.key"
        }
    },
    {
      "tag": "vmess-ws-in",
      "type": "vmess",
      "listen": "::",
      "listen_port": $VMESS_PORT,
      "users": [
      {
        "uuid": "$UUID"
      }
    ],
    "transport": {
      "type": "ws",
      "path": "/vmess-argo",
      "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    },
    {
      "tag": "tuic-in",
      "type": "tuic",
      "listen": "$available_ip",
      "listen_port": $TUIC_PORT,
      "users": [
        {
          "uuid": "$UUID",
          "password": "admin123"
        }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "alpn": [
          "h3"
        ],
        "certificate_path": "cert.pem",
        "key_path": "private.key"
      }
    }
 ],
  "outbounds": [
EOF

# in the case ofs14,set up WireGuard Leave the station
if [ "$HOSTNAME" == "s14.serv00.com" ]; then
  cat >> config.json << EOF
    {
      "type": "wireguard",
      "tag": "wireguard-out",
      "server": "162.159.195.100",
      "server_port": 4500,
      "local_address": [
        "172.16.0.2/32",
        "2606:4700:110:83c7:b31f:5858:b3a8:c6b1/128"
      ],
      "private_key": "mPZo+V9qlrMGCZ7+E6z2NI6NOV34PD++TpAR09PtCWI=",
      "peer_public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
      "reserved": [
        26,
        21,
        228
      ]
    },
EOF
fi

# Add default direct and block Leave the station
cat >> config.json << EOF
    {
      "tag": "direct",
      "type": "direct"
    },
    {
      "tag": "block",
      "type": "block"
    }
  ],
  "route": {
    "rules": [
EOF

if [ "$HOSTNAME" == "s14.serv00.com" ]; then
  cat >> config.json << EOF
      {
        "outbound": "wireguard-out",
        "domain": ["geosite:all"]
      },
      {
        "outbound": "direct",
        "domain": ["geosite:cn"]
      }
EOF
else
  cat >> config.json << EOF
      {
        "outbound": "direct",
        "domain": ["geosite:all"]
      }
EOF
fi

cat >> config.json << EOF
    ]
  }
}
EOF

}

download_singbox() {
  ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()
  if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
      FILE_INFO=("https://github.com/eooce/test/releases/download/arm64/sb web" "https://github.com/eooce/test/releases/download/arm64/bot13 bot" "https://github.com/eooce/test/releases/download/ARM/swith npm")
  elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
      FILE_INFO=("https://github.com/eooce/test/releases/download/freebsd/sb web" "https://github.com/eooce/test/releases/download/freebsd/server bot" "https://github.com/eooce/test/releases/download/freebsd/npm npm")
  else
      echo "Unsupported architecture: $ARCH"
      exit 1
  fi
declare -A FILE_MAP
generate_random_name() {
    local chars=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890
    local name=""
    for i in {1..6}; do
        name="$name${chars:RANDOM%${#chars}:1}"
    done
    echo "$name"
}

download_with_fallback() {
    local URL=$1
    local NEW_FILENAME=$2

    curl -L -sS --max-time 3 -o "$NEW_FILENAME" "$URL" &
    CURL_PID=$!
    CURL_START_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)
    
    sleep 1

    CURL_CURRENT_SIZE=$(stat -c%s "$NEW_FILENAME" 2>/dev/null || echo 0)
    
    if [ "$CURL_CURRENT_SIZE" -le "$CURL_START_SIZE" ]; then
        kill $CURL_PID 2>/dev/null
        wait $CURL_PID 2>/dev/null
        wget -q -O "$NEW_FILENAME" "$URL"
        echo -e "\e[1;32mDownloading $NEW_FILENAME by wget\e[0m"
    else
        wait $CURL_PID
        echo -e "\e[1;32mDownloading $NEW_FILENAME by curl\e[0m"
    fi
}

for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    RANDOM_NAME=$(generate_random_name)
    NEW_FILENAME="$DOWNLOAD_DIR/$RANDOM_NAME"
    
    if [ -e "$NEW_FILENAME" ]; then
        echo -e "\e[1;32m$NEW_FILENAME already exists, Skipping download\e[0m"
    else
        download_with_fallback "$URL" "$NEW_FILENAME"
    fi
    
    chmod +x "$NEW_FILENAME"
    FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$NEW_FILENAME"
done
wait

if [ -e "$(basename ${FILE_MAP[npm]})" ]; then
    tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
    if [[ "${tlsPorts[*]}" =~ "${NEZHA_PORT}" ]]; then
      NEZHA_TLS="--tls"
    else
      NEZHA_TLS=""
    fi
    if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
        export TMPDIR=$(pwd)
        nohup ./"$(basename ${FILE_MAP[npm]})" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &
        sleep 2
        pgrep -x "$(basename ${FILE_MAP[npm]})" > /dev/null && green "$(basename ${FILE_MAP[npm]}) is running" || { red "$(basename ${FILE_MAP[npm]}) is not running, restarting..."; pkill -x "$(basename ${FILE_MAP[npm]})" && nohup ./"$(basename ${FILE_MAP[npm]})" -s "${NEZHA_SERVER}:${NEZHA_PORT}" -p "${NEZHA_KEY}" ${NEZHA_TLS} >/dev/null 2>&1 & sleep 2; purple "$(basename ${FILE_MAP[npm]}) restarted"; }
    else
        purple "NEZHA variable is empty, skipping running"
    fi
fi

if [ -e "$(basename ${FILE_MAP[web]})" ]; then
    nohup ./"$(basename ${FILE_MAP[web]})" run -c config.json >/dev/null 2>&1 &
    sleep 2
    pgrep -x "$(basename ${FILE_MAP[web]})" > /dev/null && green "$(basename ${FILE_MAP[web]}) is running" || { red "$(basename ${FILE_MAP[web]}) is not running, restarting..."; pkill -x "$(basename ${FILE_MAP[web]})" && nohup ./"$(basename ${FILE_MAP[web]})" run -c config.json >/dev/null 2>&1 & sleep 2; purple "$(basename ${FILE_MAP[web]}) restarted"; }
fi

if [ -e "$(basename ${FILE_MAP[bot]})" ]; then
    if [[ $ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
      args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH}"
    elif [[ $ARGO_AUTH =~ TunnelSecret ]]; then
      args="tunnel --edge-ip-version auto --config tunnel.yml run"
    else
      args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile boot.log --loglevel info --url http://localhost:$VMESS_PORT"
    fi
    nohup ./"$(basename ${FILE_MAP[bot]})" $args >/dev/null 2>&1 &
    sleep 2
    pgrep -x "$(basename ${FILE_MAP[bot]})" > /dev/null && green "$(basename ${FILE_MAP[bot]}) is running" || { red "$(basename ${FILE_MAP[bot]}) is not running, restarting..."; pkill -x "$(basename ${FILE_MAP[bot]})" && nohup ./"$(basename ${FILE_MAP[bot]})" "${args}" >/dev/null 2>&1 & sleep 2; purple "$(basename ${FILE_MAP[bot]}) restarted"; }
fi
sleep 2
rm -f "$(basename ${FILE_MAP[npm]})" "$(basename ${FILE_MAP[web]})" "$(basename ${FILE_MAP[bot]})"
}
 
get_argodomain() {
  if [[ -n $ARGO_AUTH ]]; then
    echo "$ARGO_DOMAIN"
  else
    local retry=0
    local max_retries=6
    local argodomain=""
    while [[ $retry -lt $max_retries ]]; do
      ((retry++))
      argodomain=$(grep -oE 'https://[[:alnum:]+\.-]+\.trycloudflare\.com' boot.log | sed 's@https://@@') 
      if [[ -n $argodomain ]]; then
        break
      fi
      sleep 1
    done
    echo "$argodomain"
  fi
}

get_ip() {
  IP_LIST=($(devil vhost list | awk '/^[0-9]+/ {print $1}'))
  API_URL="https://status.eooce.com/api"
  IP=""
  THIRD_IP=${IP_LIST[2]}
  RESPONSE=$(curl -s --max-time 2 "${API_URL}/${THIRD_IP}")
  if [[ $(echo "$RESPONSE" | jq -r '.status') == "Available" ]]; then
      IP=$THIRD_IP
  else
      FIRST_IP=${IP_LIST[0]}
      RESPONSE=$(curl -s --max-time 2 "${API_URL}/${FIRST_IP}")
      
      if [[ $(echo "$RESPONSE" | jq -r '.status') == "Available" ]]; then
          IP=$FIRST_IP
      else
          IP=${IP_LIST[1]}
      fi
  fi
  echo "$IP"
}

generate_sub_link () {
[ -d "$FILE_PATH" ] || mkdir -p "$FILE_PATH"
base64 -w0 ${FILE_PATH}/list.txt > ${FILE_PATH}/${SUB_TOKEN}_v2.log
V2rayN_LINK="https://${USERNAME}.serv00.net/${SUB_TOKEN}_v2.log"
PHP_URL="https://github.com/eooce/Sing-box/releases/download/00/get_sub.php"
curl -sS "https://sublink.eooce.com/clash?config=${V2rayN_LINK}" -o ${FILE_PATH}/${SUB_TOKEN}_clash.yaml
curl -sS "https://sublink.eooce.com/singbox?config=${V2rayN_LINK}" -o ${FILE_PATH}/${SUB_TOKEN}_singbox.yaml
command -v curl &> /dev/null && curl -s -o "${FILE_PATH}/get_sub.php" "$PHP_URL" || command -v wget &> /dev/null && wget -q -O "${FILE_PATH}/get_sub.php" "$PHP_URL" || red "Warning: Neither curl nor wget is installed. You can't use the subscription"
CLASH_LINK="https://${USERNAME}.serv00.net/get_sub.php?file=${SUB_TOKEN}_clash.yaml"
SINGBOX_LINK="https://${USERNAME}.serv00.net/get_sub.php?file=${SUB_TOKEN}_singbox.yaml"
yellow "\nNode subscription link：\nClash: ${purple}${CLASH_LINK}${re}\n"   
yellow "Sing-box: ${purple}${SINGBOX_LINK}${re}\n"
yellow "V2rayN/Nekoray/Small rocket: ${purple}${V2rayN_LINK}${re}\n\n"
}

get_links(){
argodomain=$(get_argodomain)
echo -e "\e[1;32mArgoDomain:\e[1;35m${argodomain}\e[0m\n"
ISP=$(curl -s --max-time 1.5 https://speed.cloudflare.com/meta | awk -F\" '{print $26}' | sed -e 's/ /_/g' || echo "0")
get_name() { if [ "$HOSTNAME" = "s1.ct8.pl" ]; then SERVER="CT8"; else SERVER=$(echo "$HOSTNAME" | cut -d '.' -f 1); fi; echo "$SERVER"; }
NAME="$ISP-$(get_name)"

yellow "Notice：v2rayOr the verification of other software skip certificates must be set to be set totrue,otherwisehy2ortuicNodes may not be connected\n"
cat > ${FILE_PATH}/list.txt <<EOF
vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$NAME-vmss\", \"add\": \"$available_ip\", \"port\": \"$VMESS_PORT\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"\", \"path\": \"/vmess-argo?ed=2048\", \"tls\": \"\", \"sni\": \"\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)

vmess://$(echo "{ \"v\": \"2\", \"ps\": \"$NAME-vmss-argo\", \"add\": \"$CFIP\", \"port\": \"$CFPORT\", \"id\": \"$UUID\", \"aid\": \"0\", \"scy\": \"none\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$argodomain\", \"path\": \"/vmess-argo?ed=2048\", \"tls\": \"tls\", \"sni\": \"$argodomain\", \"alpn\": \"\", \"fp\": \"\"}" | base64 -w0)

hysteria2://$UUID@$available_ip:$HY2_PORT/?sni=www.bing.com&alpn=h3&insecure=1#$NAME-hy2

tuic://$UUID:admin123@$available_ip:$TUIC_PORT?sni=www.bing.com&congestion_control=bbr&udp_relay_mode=native&alpn=h3&allow_insecure=1#$NAME-tuic
EOF
cat ${FILE_PATH}/list.txt
generate_sub_link
yellow "Serv00|ct8Old kingsing-boxOne -click four protocol installation scripts(vmess-ws|vmess-ws-tls(argo)|hysteria2|tuic)\n"
echo -e "${green}issuesfeedback：${re}${yellow}https://github.com/eooce/Sing-box/issues${re}\n"
echo -e "${green}Feedback forum：${re}${yellow}https://bbs.vps8.me${re}\n"
echo -e "${green}TGFeedback group：${re}${yellow}https://t.me/vps888${re}\n"
purple "Reprinted, please be famous，Do not abuse\n"
purple "Running done!\n"
rm -rf boot.log config.json sb.log core tunnel.yml tunnel.json fake_useragent_0.2.0.json

}

install_singbox() {
    clear
    cd $WORKDIR
    check_binexec_and_port
    argo_configure
    generate_config
    download_singbox
    get_links
}
install_singbox
