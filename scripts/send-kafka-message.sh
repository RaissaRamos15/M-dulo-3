#!/bin/bash

set -e

echo "======================================"
echo "Enviando Mensagem para Kafka via API"
echo "======================================"

# Configurações
API_ENDPOINT="http://localhost:8080/api/kafka"
CONTENT="${1:-Mensagem de teste enviada via script}"
SENDER="${2:-Script CLI}"

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para verificar se a API está rodando
check_api() {
    echo -e "${YELLOW}Verificando se a API está rodando...${NC}"
    if ! curl -s "${API_ENDPOINT}/health" > /dev/null; then
        echo -e "${RED}API não está rodando!${NC}"
        echo "Execute a aplicação Spring Boot primeiro:"
        echo "  ./mvnw spring-boot:run"
        exit 1
    fi
    echo -e "${GREEN}API está rodando!${NC}"
}

# Função para verificar se Kafka está rodando
check_kafka() {
    echo -e "${YELLOW}Verificando se Kafka está rodando...${NC}"
    if ! docker ps | grep -q kafka; then
        echo -e "${RED}Kafka não está rodando!${NC}"
        echo "Execute: docker-compose up -d"
        exit 1
    fi
    echo -e "${GREEN}Kafka está rodando!${NC}"
}

# Função para enviar mensagem simples
send_simple_message() {
    echo ""
    echo -e "${BLUE}======================================"
    echo "Enviando Mensagem Simples"
    echo "======================================${NC}"
    
    PAYLOAD=$(cat <<EOF
{
    "content": "$CONTENT",
    "sender": "$SENDER"
}
EOF
)
    
    echo -e "${YELLOW}Payload:${NC}"
    echo "$PAYLOAD" | jq '.' 2>/dev/null || echo "$PAYLOAD"
    echo ""
    
    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        "${API_ENDPOINT}/send/simple")
    
    echo -e "${GREEN}Resposta da API:${NC}"
    echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
    echo ""
}

# Função para enviar mensagem completa
send_full_message() {
    echo ""
    echo -e "${BLUE}======================================"
    echo "Enviando Mensagem Completa"
    echo "======================================${NC}"
    
    MESSAGE_ID=$(uuidgen 2>/dev/null || echo "msg-$(date +%s)")
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")
    
    PAYLOAD=$(cat <<EOF
{
    "id": "$MESSAGE_ID",
    "content": "$CONTENT",
    "sender": "$SENDER",
    "timestamp": "$TIMESTAMP"
}
EOF
)
    
    echo -e "${YELLOW}Payload:${NC}"
    echo "$PAYLOAD" | jq '.' 2>/dev/null || echo "$PAYLOAD"
    echo ""
    
    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        "${API_ENDPOINT}/send")
    
    echo -e "${GREEN}Resposta da API:${NC}"
    echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
    echo ""
}

# Função para enviar múltiplas mensagens
send_multiple_messages() {
    echo ""
    echo -e "${BLUE}======================================"
    echo "Enviando Múltiplas Mensagens"
    echo "======================================${NC}"
    
    QUANTITY="${1:-5}"
    
    for i in $(seq 1 $QUANTITY); do
        echo -e "${YELLOW}Enviando mensagem $i de $QUANTITY...${NC}"
        
        PAYLOAD=$(cat <<EOF
{
    "content": "Mensagem em lote #$i - $CONTENT",
    "sender": "$SENDER"
}
EOF
)
        
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD" \
            "${API_ENDPOINT}/send/simple" > /dev/null
        
        echo -e "${GREEN}✓ Mensagem $i enviada${NC}"
        sleep 0.5
    done
    
    echo ""
    echo -e "${GREEN}Todas as $QUANTITY mensagens foram enviadas!${NC}"
}

# Função para menu interativo
show_menu() {
    echo ""
    echo -e "${BLUE}======================================"
    echo "Menu de Opções"
    echo "======================================${NC}"
    echo "1) Enviar mensagem simples"
    echo "2) Enviar mensagem completa"
    echo "3) Enviar múltiplas mensagens (5x)"
    echo "4) Enviar múltiplas mensagens (quantidade personalizada)"
    echo "5) Modo interativo - digitar mensagem"
    echo "6) Verificar saúde da API"
    echo "7) Sair"
    echo ""
    read -p "Escolha uma opção [1-7]: " choice
    
    case $choice in
        1)
            send_simple_message
            show_menu
            ;;
        2)
            send_full_message
            show_menu
            ;;
        3)
            send_multiple_messages 5
            show_menu
            ;;
        4)
            read -p "Quantas mensagens deseja enviar? " quantity
            send_multiple_messages $quantity
            show_menu
            ;;
        5)
            read -p "Digite o conteúdo da mensagem: " user_content
            read -p "Digite o remetente (Enter para padrão): " user_sender
            CONTENT="$user_content"
            SENDER="${user_sender:-Script Interativo}"
            send_simple_message
            show_menu
            ;;
        6)
            check_health
            show_menu
            ;;
        7)
            echo -e "${GREEN}Até logo!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opção inválida!${NC}"
            show_menu
            ;;
    esac
}

# Função para verificar saúde
check_health() {
    echo ""
    echo -e "${BLUE}======================================"
    echo "Verificando Saúde da API"
    echo "======================================${NC}"
    
    RESPONSE=$(curl -s "${API_ENDPOINT}/health")
    echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
    echo ""
}

# Função de ajuda
show_help() {
    echo ""
    echo "Uso: $0 [OPÇÕES] [CONTEUDO] [REMETENTE]"
    echo ""
    echo "Opções:"
    echo "  -s, --simple        Enviar mensagem simples (padrão)"
    echo "  -f, --full          Enviar mensagem completa"
    echo "  -m, --multiple N    Enviar N mensagens em lote"
    echo "  -i, --interactive   Modo interativo com menu"
    echo "  -h, --help          Exibir esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0                                           # Modo interativo"
    echo "  $0 'Olá Kafka' 'João'                        # Mensagem simples"
    echo "  $0 -s 'Teste' 'Sistema'                      # Mensagem simples explícita"
    echo "  $0 -f 'Mensagem importante' 'Admin'          # Mensagem completa"
    echo "  $0 -m 10                                     # Enviar 10 mensagens"
    echo ""
}

# Execução principal
main() {
    # Verificar argumentos
    if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        show_help
        exit 0
    fi
    
    # Verificar serviços
    check_api
    check_kafka
    
    # Processar argumentos
    if [ "$1" == "-i" ] || [ "$1" == "--interactive" ] || [ -z "$1" ]; then
        show_menu
    elif [ "$1" == "-s" ] || [ "$1" == "--simple" ]; then
        CONTENT="${2:-Mensagem de teste simples}"
        SENDER="${3:-Script CLI}"
        send_simple_message
    elif [ "$1" == "-f" ] || [ "$1" == "--full" ]; then
        CONTENT="${2:-Mensagem de teste completa}"
        SENDER="${3:-Script CLI}"
        send_full_message
    elif [ "$1" == "-m" ] || [ "$1" == "--multiple" ]; then
        QUANTITY="${2:-5}"
        send_multiple_messages $QUANTITY
    else
        # Argumentos diretos
        send_simple_message
    fi
    
    echo ""
    echo -e "${GREEN}======================================"
    echo "Operação concluída!"
    echo "======================================${NC}"
    echo ""
    echo "Verifique os logs da aplicação para ver a mensagem sendo processada."
    echo "Ou acesse o Kafka UI em: http://localhost:8090"
    echo ""
}

main "$@"