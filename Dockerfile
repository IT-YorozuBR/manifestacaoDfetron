# syntax=docker/dockerfile:1
# Consulta de Manifestação NF-e — imagem Linux.
# O acesso à SEFAZ e a leitura do certificado A1 usam PowerShell/.NET; a imagem
# instala o PowerShell 7 e o expõe como "powershell", nome que o aplicativo procura.

FROM python:3.12-slim-bookworm AS build
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libsqlcipher-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY pyproject.toml README.md ./
COPY nfe_consulta ./nfe_consulta
# Instalação editável: o aplicativo resolve dados/, secrets/ e logs/ a partir de /app.
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir -e .

FROM python:3.12-slim-bookworm
ARG TARGETARCH
ARG POWERSHELL_VERSION=7.4.6
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl libsqlcipher0 libicu72 libssl3 tzdata \
    && case "${TARGETARCH:-amd64}" in \
         amd64) PS_ARCH=x64 ;; \
         arm64) PS_ARCH=arm64 ;; \
         *) echo "Arquitetura não suportada: ${TARGETARCH}" >&2; exit 1 ;; \
       esac \
    && curl -fsSL -o /tmp/powershell.tar.gz \
         "https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/powershell-${POWERSHELL_VERSION}-linux-${PS_ARCH}.tar.gz" \
    && mkdir -p /opt/microsoft/powershell \
    && tar -xzf /tmp/powershell.tar.gz -C /opt/microsoft/powershell \
    && chmod +x /opt/microsoft/powershell/pwsh \
    && ln -s /opt/microsoft/powershell/pwsh /usr/local/bin/powershell \
    && rm /tmp/powershell.tar.gz \
    && apt-get purge -y curl && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --uid 10001 --create-home --shell /usr/sbin/nologin nfe
COPY --from=build /opt/venv /opt/venv
COPY --from=build --chown=nfe:nfe /app /app
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN mkdir -p /app/dados /app/secrets /app/logs /certificados \
    && chown -R nfe:nfe /app/dados /app/secrets /app/logs

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=0 \
    POWERSHELL_TELEMETRY_OPTOUT=1 \
    POWERSHELL_UPDATECHECK=Off \
    NFE_WEB_ENV=production \
    NFE_WEB_HOST=0.0.0.0 \
    NFE_WEB_PORT=8080 \
    NFE_AUTO_SYNC_ENABLED=1

USER nfe
WORKDIR /app
VOLUME ["/app/dados", "/app/secrets", "/app/logs"]
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD python -c "import os,urllib.request as u; u.urlopen('http://127.0.0.1:%s/healthz' % os.environ.get('NFE_WEB_PORT','8080'), timeout=4)" || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["python", "-m", "nfe_consulta.web.app"]
