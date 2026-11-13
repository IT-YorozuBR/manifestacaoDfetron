#!/bin/sh
# Prepara segredos na primeira execução e inicia o aplicativo (um único processo).
set -eu

SECRETS_DIR=/app/secrets
umask 077
mkdir -p "$SECRETS_DIR" /app/dados /app/logs

# Segredo de sessão/CSRF: gerado uma vez e preservado no volume de secrets.
if [ -z "${NFE_WEB_CSRF_SECRET:-}" ] && [ ! -s "$SECRETS_DIR/web-csrf-secret.txt" ]; then
    python -c "import secrets; print(secrets.token_urlsafe(48), end='')" > "$SECRETS_DIR/web-csrf-secret.txt"
fi

# Primeiro acesso: cria a conta inicial só se ainda não existir banco de contas.
# Depois de entrar, crie contas individuais em Atualizar > Gerenciar acessos e
# remova essas variáveis do ambiente.
if [ ! -f /app/dados/admin_accounts.db ] && [ -n "${NFE_BOOTSTRAP_ADMIN_PASSWORD:-}" ]; then
    printf '%s' "${NFE_BOOTSTRAP_ADMIN_USER:-admin}" > "$SECRETS_DIR/admin-user.txt"
    printf '%s' "$NFE_BOOTSTRAP_ADMIN_PASSWORD" > "$SECRETS_DIR/admin-password.txt"
fi

exec "$@"
