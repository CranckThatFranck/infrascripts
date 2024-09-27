#!/bin/bash

# Arquivo de log para depuração
DEBUG_LOG="/root/csf__primeiroscript_debug.log"
echo "Script iniciado em $(date)" > "$DEBUG_LOG"

# Caminho completo para o comando csf
CSF_COMMAND="/usr/sbin/csf"

# Verificar se o csf está acessível
if ! command -v "$CSF_COMMAND" &> /dev/null; then
    echo "O comando CSF não foi encontrado em $CSF_COMMAND. Verifique o caminho." >> "$DEBUG_LOG"
    exit 1
fi

# Caminho para os arquivos de log do cPanel
LOG_FILES=(
    "/usr/local/cpanel/logs/access_log"       # cPanel e Webmail
    "/var/log/maillog"                        # POP3, IMAP, SMTP
)

# Arquivo para armazenar os IPs já adicionados à whitelist
WHITELISTED_IPS_FILE="/root/csf_whitelisted_ips.log"

# Função para adicionar IP ao CSF
add_ip_to_whitelist() {
    local ip=$1
    echo "Adicionando IP $ip à whitelist do CSF" >> "$DEBUG_LOG"
    # Tentar executar o comando CSF e capturar o erro, se houver
    CSF_OUTPUT=$($CSF_COMMAND -dr "$ip" && $CSF_COMMAND -a "$ip" "Desbloqueio solicitado após login bem-sucedido" && $CSF_COMMAND -r 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "$ip" >> "$WHITELISTED_IPS_FILE"
        echo "IP $ip adicionado com sucesso à whitelist." >> "$DEBUG_LOG"
    else
        echo "Falha ao adicionar o IP $ip à whitelist. Saída do comando: $CSF_OUTPUT" >> "$DEBUG_LOG"
    fi
}

# Processar logs e encontrar IPs de logins bem-sucedidos
for LOG_FILE in "${LOG_FILES[@]}"; do
    echo "Verificando arquivo de log: $LOG_FILE" >> "$DEBUG_LOG"

    if [[ -f $LOG_FILE ]]; then
        echo "Arquivo de log $LOG_FILE encontrado." >> "$DEBUG_LOG"

        # Verificar permissões de leitura no arquivo
        if [[ -r $LOG_FILE ]]; then
            echo "Arquivo $LOG_FILE é legível." >> "$DEBUG_LOG"

            # Buscar todos os IPs do campo "X-Forwarded-For" nos logs
            IPs=$(grep -oP 'X-Forwarded-For: \K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$LOG_FILE" | sort | uniq)

            if [[ -z "$IPs" ]]; then
                echo "Nenhum IP encontrado no arquivo de log $LOG_FILE." >> "$DEBUG_LOG"
            else
                echo "IPs encontrados: $IPs" >> "$DEBUG_LOG"
            fi

            # Verificar e adicionar IPs à whitelist do CSF
            for ip in $IPs; do
                if ! grep -q "$ip" "$WHITELISTED_IPS_FILE"; then
                    echo "IP $ip não está na whitelist, adicionando..." >> "$DEBUG_LOG"
                    add_ip_to_whitelist "$ip"
                else
                    echo "IP $ip já está na whitelist." >> "$DEBUG_LOG"
