#!/bin/bash

set -e

echo "======================================"
echo "Deploy Lambda JAR no LocalStack"
echo "======================================"

FUNCTION_NAME="kafka-lambda-function"
HANDLER="com.rairai.lambda_modulo3.lambda.LambdaHandler::handleRequest"
ROLE="arn:aws:iam::000000000000:role/lambda-role"
RUNTIME="java21"
TIMEOUT=60
MEMORY=1024
REGION="us-east-1"
LOCALSTACK_ENDPOINT="http://localhost:4566"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Verificar se LocalStack está rodando
check_localstack() {
    echo -e "${YELLOW}Verificando se LocalStack está rodando...${NC}"
    if ! curl -s "${LOCALSTACK_ENDPOINT}/_localstack/health" > /dev/null 2>&1; then
        echo -e "${RED}❌ LocalStack não está rodando!${NC}"
        echo "Execute: docker-compose up -d"
        exit 1
    fi
    echo -e "${GREEN}✅ LocalStack está rodando!${NC}"
}

# Criar role IAM se não existir
create_iam_role() {
    echo -e "${YELLOW}Verificando role IAM...${NC}"
    aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region="${REGION}" \
        iam create-role \
        --role-name lambda-role \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "lambda.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }' 2>/dev/null || echo -e "${BLUE}Role já existe${NC}"
}

# Build Maven
build_maven() {
    echo -e "${YELLOW}📦 Compilando projeto Maven...${NC}"
    cd "$(dirname "$0")/.."
    
    ./mvnw clean package -DskipTests
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Erro ao compilar projeto!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Build Maven concluído!${NC}"
}

# Encontrar e validar JAR
find_jar() {
    echo -e "${YELLOW}🔍 Procurando JAR otimizado...${NC}"
    
    # Tentar JAR com shade plugin (magro)
    LAMBDA_JAR="target/lambda-modulo3-0.0.1-SNAPSHOT-lambda.jar"
    FAT_JAR="target/lambda-modulo3-0.0.1-SNAPSHOT.jar"
    
    if [ -f "$LAMBDA_JAR" ]; then
        JAR_PATH="$LAMBDA_JAR"
        JAR_SIZE=$(du -h "$JAR_PATH" | cut -f1)
        JAR_SIZE_BYTES=$(stat -f%z "$JAR_PATH" 2>/dev/null || stat -c%s "$JAR_PATH" 2>/dev/null)
        
        echo -e "${GREEN}✅ JAR otimizado encontrado: $JAR_PATH${NC}"
        echo -e "${BLUE}Tamanho: $JAR_SIZE ($JAR_SIZE_BYTES bytes)${NC}"
        
        # Verificar se é menor que 50MB
        if [ "$JAR_SIZE_BYTES" -gt 52428800 ]; then
            echo -e "${RED}⚠️  AVISO: JAR ainda está grande (>50MB)${NC}"
            echo -e "${YELLOW}LocalStack Free pode ter problemas com JARs grandes${NC}"
            echo -e "${YELLOW}Mas vamos tentar mesmo assim...${NC}"
        else
            echo -e "${GREEN}✅ Tamanho OK para Lambda!${NC}"
        fi
        
    elif [ -f "$FAT_JAR" ]; then
        JAR_PATH="$FAT_JAR"
        JAR_SIZE=$(du -h "$JAR_PATH" | cut -f1)
        JAR_SIZE_BYTES=$(stat -f%z "$JAR_PATH" 2>/dev/null || stat -c%s "$JAR_PATH" 2>/dev/null)
        
        echo -e "${YELLOW}⚠️  Usando fat JAR: $JAR_PATH${NC}"
        echo -e "${BLUE}Tamanho: $JAR_SIZE ($JAR_SIZE_BYTES bytes)${NC}"
        
        if [ "$JAR_SIZE_BYTES" -gt 52428800 ]; then
            echo -e "${RED}❌ JAR muito grande para AWS Lambda (>50MB)${NC}"
            echo -e "${YELLOW}LocalStack pode funcionar mesmo assim (modo local)${NC}"
        fi
    else
        echo -e "${RED}❌ Nenhum JAR encontrado!${NC}"
        echo "Execute: ./mvnw clean package"
        exit 1
    fi
}

# Deletar função Lambda existente
delete_existing_function() {
    echo -e "${YELLOW}Verificando função Lambda existente...${NC}"
    if aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region="${REGION}" \
        lambda get-function \
        --function-name "${FUNCTION_NAME}" 2>/dev/null > /dev/null; then
        echo -e "${YELLOW}🗑️  Deletando função existente...${NC}"
        aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
            --region="${REGION}" \
            lambda delete-function \
            --function-name "${FUNCTION_NAME}"
        echo -e "${GREEN}✅ Função antiga deletada!${NC}"
    else
        echo -e "${BLUE}Nenhuma função existente encontrada${NC}"
    fi
}

# Criar função Lambda
create_lambda_function() {
    echo -e "${YELLOW}🚀 Criando função Lambda...${NC}"
    echo -e "${BLUE}Handler: ${HANDLER}${NC}"
    echo -e "${BLUE}Runtime: ${RUNTIME}${NC}"
    echo -e "${BLUE}Memory: ${MEMORY}MB${NC}"
    echo -e "${BLUE}Timeout: ${TIMEOUT}s${NC}"
    
    aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region="${REGION}" \
        lambda create-function \
        --function-name "${FUNCTION_NAME}" \
        --runtime "${RUNTIME}" \
        --handler "${HANDLER}" \
        --role "${ROLE}" \
        --zip-file "fileb://${JAR_PATH}" \
        --timeout "${TIMEOUT}" \
        --memory-size "${MEMORY}" \
        --environment "Variables={JAVA_TOOL_OPTIONS=-XX:+TieredCompilation -XX:TieredStopAtLevel=1}" \
        > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Erro ao criar função Lambda!${NC}"
        echo -e "${YELLOW}Tentando com mais detalhes...${NC}"
        
        aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
            --region="${REGION}" \
            lambda create-function \
            --function-name "${FUNCTION_NAME}" \
            --runtime "${RUNTIME}" \
            --handler "${HANDLER}" \
            --role "${ROLE}" \
            --zip-file "fileb://${JAR_PATH}" \
            --timeout "${TIMEOUT}" \
            --memory-size "${MEMORY}"
        
        exit 1
    fi
    
    echo -e "${GREEN}✅ Função Lambda criada com sucesso!${NC}"
}

# Testar função Lambda
test_lambda_function() {
    echo -e "${YELLOW}🧪 Testando função Lambda...${NC}"
    
    PAYLOAD='{"id":"test-deploy","content":"Teste de deploy com JAR","sender":"Deploy Script"}'
    
    echo -e "${BLUE}Enviando payload:${NC}"
    echo "$PAYLOAD" | jq '.' 2>/dev/null || echo "$PAYLOAD"
    echo ""
    
    aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region="${REGION}" \
        lambda invoke \
        --function-name "${FUNCTION_NAME}" \
        --payload "${PAYLOAD}" \
        response.json > /dev/null 2>&1
    
    if [ -f response.json ]; then
        echo -e "${GREEN}✅ Lambda invocada com sucesso!${NC}"
        echo -e "${BLUE}Resposta:${NC}"
        cat response.json | jq '.' 2>/dev/null || cat response.json
        echo ""
        rm -f response.json
    else
        echo -e "${YELLOW}⚠️  Não foi possível obter resposta da Lambda${NC}"
    fi
}

# Exibir informações da função
show_function_info() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}     Informações da Função Lambda     ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    
    aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region="${REGION}" \
        lambda get-function \
        --function-name "${FUNCTION_NAME}" \
        --query 'Configuration.{Nome:FunctionName,Runtime:Runtime,Handler:Handler,Timeout:Timeout,Memory:MemorySize,CodeSize:CodeSize}' \
        --output table 2>/dev/null || echo -e "${YELLOW}Não foi possível obter informações detalhadas${NC}"
}

# Main
main() {
    echo ""
    check_localstack
    echo ""
    create_iam_role
    echo ""
    build_maven
    echo ""
    find_jar
    echo ""
    delete_existing_function
    echo ""
    create_lambda_function
    echo ""
    test_lambda_function
    echo ""
    show_function_info
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}  🎉 Deploy concluído com sucesso!  ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Para mais testes:${NC}"
    echo "  ./scripts/test-lambda.sh"
    echo ""
    echo -e "${YELLOW}Invocar manualmente:${NC}"
    echo "  aws --endpoint-url=http://localhost:4566 lambda invoke \\"
    echo "    --function-name ${FUNCTION_NAME} \\"
    echo "    --payload '{\"content\":\"teste\"}' response.json"
    echo ""
}

main