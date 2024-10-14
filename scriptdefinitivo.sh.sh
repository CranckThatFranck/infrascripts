#!/bin/bash

#Arquivos de log do cPanel/WHM
LOGIN_LOG="/usr/local/cpanel/logs/login_log"
ACCESS_LOG="/usr/local/cpanel/logs/access_log"
SCRIPT_LOG="/var/log/scriptcsf.log"

# Verifica se o arquivo de log do script existe, caso contrário cria
if [ ! -f "$SCRIPT_LOG" ]; then
    touch "$SCRIPT_LOG"
    chmod 644 "$SCRIPT_LOG"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Arquivo de log criado" >> "$SCRIPT_LOG"
fi

# Função para adicionar IP à whitelist do CSF
add_to_csf() {
    local ip="$1"
    # Adiciona o IP ao CSF
    csf -a "$ip" >> "$SCRIPT_LOG" 2>&1
    if [ $? -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Sucesso ao adicionar $ip ao CSF" >> "$SCRIPT_LOG"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Falha ao adicionar $ip ao CSF" >> "$SCRIPT_LOG"
    fi
}

# Função para buscar IPs de logins bem-sucedidos
process_logins() {
    local log_file="$1"

    # Pega o timestamp da última hora
    one_hour_ago=$(date -d "1 hour ago" '+%Y-%m-%d %H')

    # Busca entradas no arquivo de log
    grep -a "$one_hour_ago" "$log_file" | while read -r line; do
        if [[ "$line" != *"FAILED LOGIN"* ]]; then
            # Extrai o IP
            ip=$(echo "$line" | grep -oP '(\d{1,3}\.){3}\d{1,3}')
            if [ ! -z "$ip" ]; then
                # Adiciona ao CSF
                add_to_csf "$ip"
            fi
        fi
    done
}

# Processa os logs do cPanel e WHM
process_logins "$LOGIN_LOG"
process_logins "$ACCESS_LOG"

# Registro de finalização do script
echo "$(date '+%Y-%m-%d %H:%M:%S') - Script finalizado" >> "$SCRIPT_LOG"

# Finaliza o script para que possa ser executado novamente
exit 0
