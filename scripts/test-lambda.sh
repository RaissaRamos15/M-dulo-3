#!/bin/bash

set -e

echo "======================================"
echo "Testando Lambda Function"
echo "======================================"

# Configurações
FUNCTION_NAME="kafka-lambda-function"
REGION="us-east-1"
LOCALSTACK_ENDPOINT="http://localhost:4566"

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Função para verificar se LocalStack está rodando
check_localstack() {
    echo -e "${YELLOW}Verificando se LocalStack está rodando...${NC}"
    if ! curl -s "${LOCALSTACK_ENDPOINT}/_localstack/health" > /dev/null; then
        echo -e "${RED}LocalStack não está rodando!${NC}"
        echo "Execute: docker-compose up -d"
        exit 1
    fi
    echo -e "${GREEN}LocalStack está rodando!${NC}"
}

# Função para verificar se a Lambda existe
check_lambda_exists() {
    echo -e "${YELLOW}Verificando se função Lambda existe...${NC}"
    if ! aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region="${REGION}" \
        lambda get-function \
        --function-name "${FUNCTION_NAME}" > /dev/null 2>&1; then
        echo -e "${RED}Função Lambda não encontrada!${NC}"
        echo "Execute: ./scripts/deploy-lambda.sh"
        exit 1
    fi
    echo -e "${GREEN}Função Lambda encontrada!${NC}"
}

# Teste 1: Mensagem simples
test_simple_message() {
    echo ""
    echo -e "${YELLOW}===========================================${NC}"
    echo -e "${YELLOW}Teste 1: Mensagem Simples${NC}"
    echo -e "${YELLOW}===========================================${NC}"
    
    PAYLOAD='{
        "id": "msg-001",
        "content": "Olá do script de teste!",
        "sender": "Test Script",
        "timestamp": "2024-01-15T10:30:00"
    }'
    
    echo "Payload enviado:"
    echo "$PAYLOAD" | jq '.'
    echo ""
    
    aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region="${REGION}" \
        lambda invoke \
        --function-name "${FUNCTION_NAME}" \
        --payload "$PAYLOAD" \
        --cli-binary-format raw-in-base64-out \
        response1.json
    
    echo -e "${GREEN}Resposta:${NC}"
    cat response1.json | jq '.' || cat response1.json
    echo ""
    rm -f response1.json
}

# Teste 2: Mensagem com conteúdo complexo
test_complex_message() {
    echo ""
    echo -e "${YELLOW}===========================================${NC}"
    echo -e "${YELLOW}Teste 2: Mensagem Complexa${NC}"
    echo -e "${YELLOW}===========================================${NC}"
    
    PAYLOAD='{
        "id": "msg-002",
        "content": "Mensagem de teste com informações detalhadas - Lambda + Kafka Integration",
        "sender": "Sistema de Testes Automatizados",
        "timestamp": "2024-01-15T11:45:00"
    }'
    
    echo "Payload enviado:"
    echo "$PAYLOAD" | jq '.'
    echo ""
    
    aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region="${REGION}" \
        lambda invoke \
        --function-name "${FUNCTION_NAME}" \
        --payload "$PAYLOAD" \
        --cli-binary-format raw-in-base64-out \
        response2.json
    
    echo -e "${GREEN}Resposta:${NC}"
    cat response2.json | jq '.' || cat response2.json
    echo ""
    rm -f response2.json
}

# Teste 3: Mensagem sem ID (será gerado automaticamente)
test_message_without_id() {
    echo ""
    echo -e "${YELLOW}===========================================${NC}"
    echo -e "${YELLOW}Teste 3: Mensagem sem ID (auto-gerado)${NC}"
    echo -e "${YELLOW}===========================================${NC}"
    
    PAYLOAD='{
        "content": "Teste sem ID predefinido",
        "sender": "Auto Test"
    }'
    
    echo "Payload enviado:"
    echo "$PAYLOAD" | jq '.'
    echo ""
    
    aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region="${REGION}" \
        lambda invoke \
        --function-name "${FUNCTION_NAME}" \
        --payload "$PAYLOAD" \
        --cli-binary-format raw-in-base64-out \
        response3.json
    
    echo -e "${GREEN}Resposta:${NC}"
    cat response3.json | jq '.' || cat response3.json
    echo ""
    rm -f response3.json
}

# Teste 4: Múltiplas invocações
test_multiple_invocations() {
    echo ""
    echo -e "${YELLOW}===========================================${NC}"
    echo -e "${YELLOW}Teste 4: Múltiplas Invocações (5x)${NC}"
    echo -e "${YELLOW}===========================================${NC}"
    
    for i in {1..5}; do
        echo -e "${YELLOW}Invocação #$i${NC}"
        
        PAYLOAD=$(cat <<EOF
{
    "id": "batch-msg-$i",
    "content": "Mensagem em lote número $i",
    "sender": "Batch Test",
    "timestamp": "2024-01-15T12:00:0$i"
}
EOF
)
        
        aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
            --region="${REGION}" \
            lambda invoke \
            --function-name "${FUNCTION_NAME}" \
            --payload "$PAYLOAD" \
            --cli-binary-format raw-in-base64-out \
            response_batch_$i.json > /dev/null 2>&1
        
        echo -e "${GREEN}✓ Mensagem $i enviada${NC}"
        sleep 1
    done
    
    echo ""
    echo -e "${GREEN}Todas as mensagens em lote foram enviadas!${NC}"
    rm -f response_batch_*.json
}

# Teste 5: Formato de evento MSK simulado
test_msk_event_format() {
    echo ""
    echo -e "${YELLOW}===========================================${NC}"
    echo -e "${YELLOW}Teste 5: Formato de Evento MSK${NC}"
    echo -e "${YELLOW}===========================================${NC}"
    
    PAYLOAD='{
        "eventSource": "aws:kafka",
        "eventSourceArn": "arn:aws:kafka:us-east-1:123456789012:cluster/demo-cluster/11111111-1111-1111-1111-111111111111-1",
        "records": {
            "lambda-topic-0": [
                {
                    "topic": "lambda-topic",
                    "partition": 0,
                    "offset": 0,
                    "timestamp": 1640000000000,
                    "timestampType": "CREATE_TIME",
                    "key": "msg-msk-001",
                    "value": "{\"id\":\"msg-msk-001\",\"content\":\"Mensagem no formato MSK\",\"sender\":\"MSK Test\",\"timestamp\":\"2024-01-15T13:00:00\"}",
                    "headers": []
                }
            ]
        }
    }'
    
    echo "Payload MSK enviado:"
    echo "$PAYLOAD" | jq '.'
    echo ""
    
    aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region="${REGION}" \
        lambda invoke \
        --function-name "${FUNCTION_NAME}" \
        --payload "$PAYLOAD" \
        --cli-binary-format raw-in-base64-out \
        response5.json
    
    echo -e "${GREEN}Resposta:${NC}"
    cat response5.json | jq '.' || cat response5.json
    echo ""
    rm -f response5.json
}

# Função para exibir logs da Lambda
show_lambda_logs() {
    echo ""
    echo -e "${YELLOW}===========================================${NC}"
    echo -e "${YELLOW}Logs da Lambda (últimas 20 linhas)${NC}"
    echo -e "${YELLOW}===========================================${NC}"
    
    # No LocalStack, os logs podem estar disponíveis via CloudWatch Logs
    aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region="${REGION}" \
        logs tail "/aws/lambda/${FUNCTION_NAME}" \
        --follow --since 5m 2>/dev/null || echo -e "${YELLOW}Logs não disponíveis ou comando não suportado no LocalStack${NC}"
}

# Execução principal
main() {
    check_localstack
    check_lambda_exists
    
    echo ""
    echo -e "${GREEN}Iniciando testes da função Lambda...${NC}"
    
    test_simple_message
    sleep 2
    
    test_complex_message
    sleep 2
    
    test_message_without_id
    sleep 2
    
    test_multiple_invocations
    sleep 2
    
    test_msk_event_format
    
    echo ""
    echo -e "${GREEN}======================================"
    echo "Todos os testes foram concluídos!"
    echo "======================================${NC}"
    echo ""
    echo "Verifique os logs da aplicação Spring Boot para ver as mensagens processadas pelo Kafka Listener."
    echo ""
}

main