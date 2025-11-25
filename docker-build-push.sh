#!/bin/bash

set -e

echo "======================================"
echo "Build e Push para Docker Hub"
echo "======================================"

# Configurações
DOCKER_USERNAME="${DOCKER_USERNAME:-seunome}"
IMAGE_NAME="lambda-modulo3"
VERSION="${VERSION:-latest}"
FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Verificar se Docker está rodando
check_docker() {
    echo -e "${YELLOW}Verificando Docker...${NC}"
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker não está rodando!${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker está rodando!${NC}"
}

# Verificar se está logado no Docker Hub
check_docker_login() {
    echo -e "${YELLOW}Verificando login no Docker Hub...${NC}"
    if ! docker info | grep -q "Username"; then
        echo -e "${YELLOW}⚠️  Você não está logado no Docker Hub${NC}"
        echo -e "${BLUE}Fazendo login...${NC}"
        docker login
    else
        echo -e "${GREEN}✅ Já está logado no Docker Hub!${NC}"
    fi
}

# Compilar aplicação
build_app() {
    echo -e "${YELLOW}📦 Compilando aplicação Maven...${NC}"
    ./mvnw clean package -DskipTests
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Erro ao compilar!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Compilação concluída!${NC}"
}

# Build da imagem Docker
build_image() {
    echo -e "${YELLOW}🐳 Construindo imagem Docker...${NC}"
    echo -e "${BLUE}Imagem: ${FULL_IMAGE_NAME}${NC}"
    
    docker build -f Dockerfile.app -t ${FULL_IMAGE_NAME} .
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Erro ao construir imagem!${NC}"
        exit 1
    fi
    
    # Também taguear como latest se não for
    if [ "$VERSION" != "latest" ]; then
        docker tag ${FULL_IMAGE_NAME} ${DOCKER_USERNAME}/${IMAGE_NAME}:latest
        echo -e "${GREEN}✅ Também tagueada como latest${NC}"
    fi
    
    echo -e "${GREEN}✅ Imagem construída com sucesso!${NC}"
    
    # Mostrar tamanho
    IMAGE_SIZE=$(docker images ${FULL_IMAGE_NAME} --format "{{.Size}}")
    echo -e "${BLUE}Tamanho da imagem: ${IMAGE_SIZE}${NC}"
}

# Testar imagem localmente
test_image() {
    echo -e "${YELLOW}🧪 Testando imagem localmente...${NC}"
    
    # Parar container se já existir
    docker rm -f lambda-test 2>/dev/null || true
    
    echo -e "${BLUE}Iniciando container de teste...${NC}"
    docker run -d \
        --name lambda-test \
        -p 8081:8080 \
        -e SPRING_KAFKA_BOOTSTRAP_SERVERS=localhost:9092 \
        ${FULL_IMAGE_NAME}
    
    # Aguardar aplicação iniciar
    echo -e "${YELLOW}Aguardando aplicação iniciar (30s)...${NC}"
    sleep 30
    
    # Testar health endpoint
    if curl -f http://localhost:8081/api/kafka/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Imagem funcionando corretamente!${NC}"
    else
        echo -e "${YELLOW}⚠️  Health check falhou, mas imagem foi criada${NC}"
    fi
    
    # Parar container de teste
    docker stop lambda-test > /dev/null 2>&1
    docker rm lambda-test > /dev/null 2>&1
    
    echo -e "${BLUE}Container de teste removido${NC}"
}

# Push para Docker Hub
push_image() {
    echo -e "${YELLOW}⬆️  Enviando para Docker Hub...${NC}"
    echo -e "${BLUE}Imagem: ${FULL_IMAGE_NAME}${NC}"
    
    docker push ${FULL_IMAGE_NAME}
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Erro ao enviar imagem!${NC}"
        exit 1
    fi
    
    # Push da tag latest também se aplicável
    if [ "$VERSION" != "latest" ]; then
        docker push ${DOCKER_USERNAME}/${IMAGE_NAME}:latest
    fi
    
    echo -e "${GREEN}✅ Imagem enviada com sucesso!${NC}"
}

# Exibir informações finais
show_info() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${GREEN}   🎉 Build e Push concluídos!   ${NC}"
    echo -e "${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Imagem disponível em:${NC}"
    echo -e "  ${FULL_IMAGE_NAME}"
    echo ""
    echo -e "${YELLOW}Para usar a imagem:${NC}"
    echo ""
    echo -e "${BLUE}# Pull da imagem${NC}"
    echo "  docker pull ${FULL_IMAGE_NAME}"
    echo ""
    echo -e "${BLUE}# Rodar localmente${NC}"
    echo "  docker run -p 8080:8080 ${FULL_IMAGE_NAME}"
    echo ""
    echo -e "${BLUE}# Usar no docker-compose.yaml${NC}"
    echo "  services:"
    echo "    app:"
    echo "      image: ${FULL_IMAGE_NAME}"
    echo "      ports:"
    echo "        - '8080:8080'"
    echo ""
    echo -e "${YELLOW}Ver no Docker Hub:${NC}"
    echo "  https://hub.docker.com/r/${DOCKER_USERNAME}/${IMAGE_NAME}"
    echo ""
}

# Menu interativo
show_menu() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}   Opções de Build e Push   ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo "1) Build completo + Push (recomendado)"
    echo "2) Apenas build (sem push)"
    echo "3) Apenas push (já buildou antes)"
    echo "4) Build + Test local (sem push)"
    echo "5) Sair"
    echo ""
    read -p "Escolha uma opção [1-5]: " choice
    
    case $choice in
        1)
            check_docker
            check_docker_login
            build_app
            build_image
            test_image
            push_image
            show_info
            ;;
        2)
            check_docker
            build_app
            build_image
            echo -e "${GREEN}✅ Build concluído! Use opção 3 para fazer push.${NC}"
            ;;
        3)
            check_docker
            check_docker_login
            push_image
            show_info
            ;;
        4)
            check_docker
            build_app
            build_image
            test_image
            echo -e "${GREEN}✅ Build e teste concluídos!${NC}"
            ;;
        5)
            echo -e "${BLUE}Até logo!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opção inválida!${NC}"
            show_menu
            ;;
    esac
}

# Função de ajuda
show_help() {
    echo ""
    echo "Uso: $0 [OPÇÕES]"
    echo ""
    echo "Opções:"
    echo "  -u, --username USERNAME    Nome de usuário do Docker Hub (padrão: seunome)"
    echo "  -v, --version VERSION      Versão da imagem (padrão: latest)"
    echo "  -n, --no-push              Apenas build, não fazer push"
    echo "  -t, --test                 Testar imagem localmente após build"
    echo "  -h, --help                 Exibir esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  $0                                    # Modo interativo"
    echo "  $0 -u seunome -v 1.0.0                # Build e push versão 1.0.0"
    echo "  $0 -u seunome --no-push               # Apenas build local"
    echo "  $0 -u seunome -v 1.0.0 --test         # Build, test, push"
    echo ""
    echo "Variáveis de ambiente:"
    echo "  DOCKER_USERNAME    Nome de usuário do Docker Hub"
    echo "  VERSION            Versão da imagem"
    echo ""
}

# Parse argumentos
NO_PUSH=false
TEST_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--username)
            DOCKER_USERNAME="$2"
            FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            FULL_IMAGE_NAME="${DOCKER_USERNAME}/${IMAGE_NAME}:${VERSION}"
            shift 2
            ;;
        -n|--no-push)
            NO_PUSH=true
            shift
            ;;
        -t|--test)
            TEST_ONLY=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Opção desconhecida: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Execução principal
main() {
    # Se não tiver argumentos, mostrar menu
    if [ "$NO_PUSH" = false ] && [ "$TEST_ONLY" = false ] && [ -z "$2" ]; then
        show_menu
    else
        # Execução com argumentos
        check_docker
        
        if [ "$NO_PUSH" = false ]; then
            check_docker_login
        fi
        
        build_app
        build_image
        
        if [ "$TEST_ONLY" = true ]; then
            test_image
        fi
        
        if [ "$NO_PUSH" = false ]; then
            push_image
            show_info
        else
            echo -e "${GREEN}✅ Build concluído (sem push)!${NC}"
        fi
    fi
}

main "$@"