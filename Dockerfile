# Stage 1: Installer
FROM node:20-bullseye AS installer

# Instalar dependências do sistema necessárias para npm build
RUN apt-get update && apt-get install -y python3 make g++ git curl && rm -rf /var/lib/apt/lists/*

WORKDIR /juice-shop

# Copiar package.json e package-lock.json primeiro para cache do Docker
COPY package*.json frontend/package*.json frontend/package-lock*.json ./

# Instalar TypeScript globalmente
RUN npm i -g typescript ts-node

# Instalar dependências do backend e frontend
RUN npm install --omit=dev --unsafe-perm
RUN npm dedupe --omit=dev

# Remover node_modules do frontend para reduzir tamanho
RUN rm -rf frontend/node_modules frontend/.angular frontend/src/assets

# Preparar diretórios e permissões
RUN mkdir logs
RUN chown -R 65532 logs
RUN chgrp -R 0 ftp/ frontend/dist/ logs/ data/ i18n/
RUN chmod -R g=u ftp/ frontend/dist/ logs/ data/ i18n/

# Remover arquivos sensíveis ou temporários
RUN rm -f data/chatbot/botDefaultTrainingData.json || true
RUN rm -f ftp/legal.md || true
RUN rm -f i18n/*.json || true

# Gerar SBOM
ARG CYCLONEDX_NPM_VERSION=latest
RUN npm install -g @cyclonedx/cyclonedx-npm@$CYCLONEDX_NPM_VERSION
RUN npm run sbom

# Stage 2: Runtime
FROM gcr.io/distroless/nodejs20-debian12

ARG BUILD_DATE
ARG VCS_REF

LABEL maintainer="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
      org.opencontainers.image.title="OWASP Juice Shop" \
      org.opencontainers.image.description="Probably the most modern and sophisticated insecure web application" \
      org.opencontainers.image.authors="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
      org.opencontainers.image.vendor="Open Worldwide Application Security Project" \
      org.opencontainers.image.documentation="https://help.owasp-juice.shop" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="19.0.0" \
      org.opencontainers.image.url="https://owasp-juice.shop" \
      org.opencontainers.image.source="https://github.com/juice-shop/juice-shop" \
      org.opencontainers.image.revision=$VCS_REF \
      org.opencontainers.image.created=$BUILD_DATE

WORKDIR /juice-shop
COPY --from=installer --chown=65532:0 /juice-shop .

USER 65532
EXPOSE 3000
CMD ["/juice-shop/build/app.js"]
