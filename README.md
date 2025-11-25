**Projeto**: Lambda Módulo 3

- **Descrição**: Projeto Java (Spring Boot) que demonstra integração com Kafka e empacotamento para execução como AWS Lambda e como aplicação Dockerizada.

**Visão Geral**:
- **Objetivo**: produzir uma imagem de Lambda Java 21 contendo as classes compiladas e as dependências, além de uma imagem de aplicação (App).
- **Componentes**: produtor/consumidor Kafka, handlers Lambda, configuração Spring Boot.

**Requisitos**:
- **Java**: JDK 21 (usado no CI e para empacotar localmente)
- **Maven**: versão compatível com o projeto (o wrapper `./mvnw` é fornecido)
- **Docker**: para construir imagens locais/CI

**Como buildar localmente**:
- **Passo 1 — Compilar e copiar dependências**: o Dockerfile da Lambda espera as dependências em `target/lib`. Execute:

```bash
chmod +x mvnw
./mvnw clean package -DskipTests
./mvnw dependency:copy-dependencies -DoutputDirectory=target/lib
```

- **Passo 2 — Build da imagem Lambda (local)**:

```bash
# build da imagem Lambda usando o Dockerfile da raiz
docker build -f Dockerfile -t lambda-modulo3:local .
```

- **Passo 3 — Build da imagem App (local)**:

```bash
docker build -f Dockerfile.app -t lambda-modulo3-app:local .
```

Observação: se você preferir não alterar o build Maven, o Dockerfile pode ser adaptado para copiar de `target/dependency/` em vez de `target/lib/` — veja a seção "Erros comuns".

**Dockerfile (pontos importantes)**:
- O `Dockerfile` usado para a Lambda baseia-se na imagem oficial `public.ecr.aws/lambda/java:21`.
- Ele copia as dependências para `${LAMBDA_TASK_ROOT}/lib/` e as classes para `${LAMBDA_TASK_ROOT}/`.
- Linha relevante no repositório:

```dockerfile
# Copiar dependências para o runtime da Lambda
COPY target/lib/ ${LAMBDA_TASK_ROOT}/lib/
# Copiar classes compiladas da aplicação
COPY target/classes/ ${LAMBDA_TASK_ROOT}/
```

**Pipeline / CI (GitHub Actions)**:
- Workflow: `.github/workflows/docker-push.yml` — ele:
	- faz checkout do código
	- configura JDK 21
	- roda `./mvnw clean package -DskipTests` e `dependency:copy-dependencies -DoutputDirectory=target/lib`
	- configura o Buildx e faz login no Docker Hub
	- gera metadados e faz build/push das imagens `IMAGE_LAMBDA` e `IMAGE_APP`

Trecho do passo que constrói a imagem Lambda (no workflow):

```yaml
- name: Build and push Lambda image
	uses: docker/build-push-action@v5
	with:
		context: .
		file: ./Dockerfile
		push: true
		tags: ${{ steps.meta-lambda.outputs.tags }}
		labels: ${{ steps.meta-lambda.outputs.labels }}
```

**Erros comuns e soluções**:
- Erro: `failed to calculate checksum ... "/target/lib": not found` — causa: o diretório `target/lib` não existe no contexto de build.
	- Solução A (recomendada): atualizar o passo de build Maven para copiar dependências para `target/lib` com:

```bash
./mvnw dependency:copy-dependencies -DoutputDirectory=target/lib
```

	- Solução B: alterar o `Dockerfile` para usar `target/dependency/` (padrão do Maven) em vez de `target/lib/`:

```dockerfile
COPY target/dependency/ ${LAMBDA_TASK_ROOT}/lib/
```

	- Solução C: garantir que `.dockerignore` não esteja excluindo `target/` (verifique e remova `target` se presente).

**Estrutura do projeto (resumo)**:
- `src/main/java/com/rairai/lambda_modulo3/` — código fonte
- `src/main/resources/application.properties` — configurações
- `Dockerfile` — imagem Lambda baseada em `public.ecr.aws/lambda/java:21`
- `Dockerfile.app` — imagem da aplicação
- `.github/workflows/docker-push.yml` — build e push das imagens no CI

**Comandos úteis para debugging local**:

```bash
# Ver conteúdo do .dockerignore
cat .dockerignore

# Garantir que target/lib existe
ls -la target/lib || echo "target/lib não existe"

# Rodar build Docker em modo verboso
docker build -f Dockerfile . --progress=plain
```

**Testes**:
- O projeto contém testes unitários em `src/test/java`.
- Para executar os testes localmente:

```bash
./mvnw test
```


