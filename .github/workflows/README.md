# GitHub Actions - Docker Hub

Este workflow automatiza o build e push das imagens Docker para o Docker Hub.

## 📦 Arquivo

- `docker-push.yml` - Build e push automático para Docker Hub

## 🎯 O Que Faz

1. Compila o projeto Maven
2. Cria 2 imagens Docker:
   - `{seu-usuario}/lambda-modulo3` (do `Dockerfile`)
   - `{seu-usuario}/lambda-modulo3-app` (do `Dockerfile.app`)
3. Envia automaticamente para o Docker Hub

## ⚙️ Configuração

### Secrets Necessários

Configure no GitHub: **Settings → Secrets and variables → Actions**

| Secret | Descrição |
|--------|-----------|
| `DOCKERHUB_USERNAME` | Seu usuário do Docker Hub |
| `DOCKERHUB_TOKEN` | Token de acesso do Docker Hub |

### Como Criar o Token

1. Acesse: https://hub.docker.com/settings/security
2. Clique em "New Access Token"
3. Nome: `github-actions`
4. Copie o token gerado

## 🚀 Quando Executa

- Push para `main`, `master`, `develop`
- Criação de tags `v*` (ex: `v1.0.0`)
- Execução manual (workflow_dispatch)

## 🏷️ Tags Geradas

| Ação | Tags |
|------|------|
| Push no `main` | `latest`, `main` |
| Push no `develop` | `develop` |
| Tag `v1.2.3` | `v1.2.3`, `1.2`, `1`, `latest` |

## 📝 Exemplo de Uso

```bash
# Criar versão
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions automaticamente:
# - Compila o Maven
# - Cria as imagens Docker
# - Envia para Docker Hub

# Usar as imagens
docker pull {seu-usuario}/lambda-modulo3:latest
docker pull {seu-usuario}/lambda-modulo3-app:latest
```

## 📚 Documentação Completa

Veja o arquivo `GITHUB-ACTIONS-SETUP.md` na raiz do projeto para instruções detalhadas.