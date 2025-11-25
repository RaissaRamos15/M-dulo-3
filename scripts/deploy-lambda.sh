#!/bin/bash

set -e

echo "======================================"
echo "Deploy Lambda Container no LocalStack"
echo "======================================"

FUNCTION_NAME="kafka-lambda-function"
IMAGE_NAME="kafka-lambda"
REGION="us-east-1"
LOCALSTACK_ENDPOINT="http://localhost:4566"
ROLE="arn:aws:iam::000000000000:role/lambda-role"

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
        echo "Execute: docker-compose up -d localstack"
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

# Build da aplicação Maven
build_maven() {
    echo -e "${YELLOW}📦 Compilando projeto Maven...${NC}"
    ./mvnw clean package -DskipTests
    
    if [ ! -d "target/classes" ]; then
        echo -e "${RED}❌ Erro: target/classes não foi criado!${NC}"
        exit 1
    fi
    
    if [ ! -d "target/lib" ]; then
        echo -e "${RED}❌ Erro: target/lib não foi criado!${NC}"
        echo "Verifique se o maven-dependency-plugin está configurado no pom.xml"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Build Maven concluído!${NC}"
    echo -e "${BLUE}Classes: $(find target/classes -name '*.class' | wc -l) arquivos${NC}"
    echo -e "${BLUE}Dependências: $(ls target/lib | wc -l) JARs${NC}"
}

# Build da imagem Docker
build_docker_image() {
    echo -e "${YELLOW}🐳 Construindo imagem Docker...${NC}"
    docker build -t ${IMAGE_NAME}:latest .
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Erro ao construir imagem Docker!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Imagem Docker criada!${NC}"
    
    # Mostrar tamanho da imagem
    IMAGE_SIZE=$(docker images ${IMAGE_NAME}:latest --format "{{.Size}}")
    echo -e "${BLUE}Tamanho da imagem: ${IMAGE_SIZE}${NC}"
}

# Preparar imagem para LocalStack
prepare_image_for_localstack() {
    echo -e "${YELLOW}📦 Preparando imagem para LocalStack...${NC}"
    
    # LocalStack pode usar imagens locais diretamente
    # Não precisa fazer push para registry
    echo -e "${GREEN}✅ Imagem local pronta para uso!${NC}"
    echo -e "${BLUE}LocalStack irá usar: ${IMAGE_NAME}:latest${NC}"
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

# Criar função Lambda com container
create_lambda_function() {
    echo -e "${YELLOW}🚀 Criando função Lambda a partir do container...${NC}"
    
    aws --endpoint-url="${LOCALSTACK_ENDPOINT}" \
        --region="${REGION}" \
        lambda create-function \
        --function-name "${FUNCTION_NAME}" \
        --package-type Image \
        --code ImageUri=${IMAGE_NAME}:latest \
        --role "${ROLE}" \
        --timeout 60 \
        --memory-size 512 \
        --environment "Variables={SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka:29092}"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Erro ao criar função Lambda!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Função Lambda criada com sucesso!${NC}"
}

# Testar a função Lambda
test_lambda_function() {
    echo -e "${YELLOW}🧪 Testando função Lambda...${NC}"
    
    PAYLOAD='{"id":"test-001","content":"Teste de deploy via container","sender":"Deploy Script","timestamp":"2024-01-15T10:00:00"}'
    
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
        rm -f response.json
    else
        echo -e "${YELLOW}Não foi possível obter resposta da Lambda${NC}"
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
        --query 'Configuration.{Nome:FunctionName,PackageType:PackageType,Timeout:Timeout,Memory:MemorySize,Handler:Handler}' \
        --output table
}

# Execução principal
main() {
    echo ""
    check_localstack
    echo ""
    create_iam_role
    echo ""
    build_maven
    echo ""
    build_docker_image
    echo ""
    prepare_image_for_localstack
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
    echo -e "${GREEN}     🎉 Deploy concluído com sucesso!     ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Para testar mais:${NC}"
    echo "  ./scripts/test-lambda.sh"
    echo ""
    echo -e "${YELLOW}Para invocar manualmente:${NC}"
    echo "  aws --endpoint-url=http://localhost:4566 lambda invoke --function-name ${FUNCTION_NAME} --payload '{\"content\":\"teste\"}' response.json"
    echo ""
}

main
