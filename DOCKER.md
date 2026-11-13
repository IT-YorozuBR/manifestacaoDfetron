# Execução em container

Imagem Linux com um único processo/worker. A leitura do certificado A1 e as chamadas à SEFAZ usam PowerShell/.NET, então a imagem inclui o PowerShell 7 (`powershell`). Use **certificado por arquivo (.pfx/.p12)**; o repositório de certificados do Windows não existe no container.

## Subir

```bash
mkdir certificados                      # coloque aqui o seu .pfx
printf 'NFE_BOOTSTRAP_ADMIN_USER=admin\nNFE_BOOTSTRAP_ADMIN_PASSWORD=<senha-forte>\n' > .env
docker compose up -d --build
docker compose logs -f
```

Acesse `http://127.0.0.1:8080` (porta publicada só no host). Em **Atualizar**, informe o banco e o certificado (`/certificados/arquivo.pfx` e a senha).

Depois do primeiro acesso, crie contas individuais em **Atualizar → Gerenciar acessos** e remova `NFE_BOOTSTRAP_ADMIN_PASSWORD` do `.env`. Ela só é usada enquanto `dados/admin_accounts.db` não existe.

## Dados

Volumes nomeados: `dados` (bancos), `secrets` (senhas, caminho do banco/certificado, segredo de sessão) e `logs`. Sobrevivem a `docker compose down`; `down -v` apaga tudo, inclusive o cursor NSU.

Para levar um banco fiscal existente (com o container parado, mantendo o mesmo cursor NSU):

```bash
docker compose create
docker compose cp nfe_manifestacoes_seguro.db nfe-consulta:/app/dados/
docker compose run --rm --user root --entrypoint chown nfe-consulta 10001:10001 /app/dados/nfe_manifestacoes_seguro.db
docker compose up -d
```

Se o banco usa SQLCipher, grave a senha em `secrets/db-password.txt` dentro do volume.

Backup: pare o container e copie os volumes `dados` e `secrets`.

## Hospedagem

- Coloque um reverse proxy com **HTTPS** na frente (Caddy, Nginx, Traefik). Os cookies de produção são `Secure`.
- Rode **uma instância só** contra o mesmo banco.
- A sincronização automática roda a cada hora das 22h às 03h (Brasília), com fechamento às 04h, enquanto o container estiver ativo; `restart: unless-stopped` mantém o serviço no ar.
- Variáveis de ambiente suportadas: as de `SERVIDOR_WEB.md` (SMTP, cooldown, intervalo etc.).
