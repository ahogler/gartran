# 🚀 Deploy com GitHub Actions — Gartran

## Visão Geral

O Gartran usa **GitHub Actions** com **appleboy/ssh-action** e **appleboy/scp-action** para deploy automático na VPS Hostinger.

**Fluxo:**
1. Push para `master` ou merge de PR → GitHub Actions dispara
2. Build (.NET 9) e testes E2E
3. Publica API + Blazor WASM
4. SSH para VPS + transfer de arquivos
5. Executa script de deploy seguro
6. Health check
7. Notificação de status

---

## 📋 GitHub Secrets Necessários

Adicione estes secrets em **GitHub → Settings → Secrets and variables → Actions**:

| Secret | Valor | Descrição |
|--------|-------|-----------|
| `VPS_HOST` | IP ou domínio da VPS | Ex: `123.456.789.100` |
| `VPS_USERNAME` | Usuário SSH | Ex: `ubuntu` ou `root` |
| `VPS_SSH_KEY` | Private SSH key (sem passphrase) | Conteúdo de `~/.ssh/id_rsa` |

---

## 🔑 Gerando SSH Key (Se Não Tiver)

### Na sua máquina local:
```bash
ssh-keygen -t ed25519 -f ~/.ssh/gartran_deploy -C "gartran-deploy@github"
# Deixe passphrase vazia quando perguntado
```

### Copiar chave privada:
```bash
cat ~/.ssh/gartran_deploy
```
**Cole esse conteúdo em `VPS_SSH_KEY`** no GitHub.

### Na VPS (Hostinger):
```bash
# Login na VPS
ssh ubuntu@<VPS_IP>

# Adicionar chave pública ao authorized_keys
mkdir -p ~/.ssh
cat >> ~/.ssh/authorized_keys << 'EOF'
[cole conteúdo de ~/.ssh/gartran_deploy.pub aqui]
EOF

chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

---

## 🛡️ Considerações de Segurança (VPS Compartilhada)

Como você já tem outros projetos .NET rodando, **tome cuidado:**

### 1. Serviço Isolado
```bash
# Criar usuário gartran
sudo useradd -m -s /bin/bash gartran

# Dar acesso ao deploy directory
sudo chown gartran:gartran /opt/gartran
```

### 2. systemd Service (gartran.service)
```ini
[Unit]
Description=Gartran API
After=network.target postgresql.service

[Service]
Type=notify
User=gartran
WorkingDirectory=/opt/gartran
ExecStart=/usr/bin/dotnet /opt/gartran/PortalGartran.Server.dll
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=10
Environment="ASPNETCORE_URLS=http://localhost:8080"
Environment="ASPNETCORE_ENVIRONMENT=Production"

[Install]
WantedBy=multi-user.target
```

**Instalar na VPS:**
```bash
sudo nano /etc/systemd/system/gartran.service
# Cole o conteúdo acima, depois:
sudo systemctl daemon-reload
sudo systemctl enable gartran
```

### 3. Proxy Reverso (Nginx)
Se você quer compartilhar HTTPS entre múltiplos projetos:

```nginx
upstream gartran {
    server localhost:8080;
}

server {
    server_name gartran.seu-dominio.com;
    
    location / {
        proxy_pass http://gartran;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 📝 Portas Recomendadas

**Não use porta 80/443 diretamente** em produção com múltiplos projetos:

| Projeto | Porta Interna | Via Proxy |
|---------|---------------|-----------|
| FlashCar | 8000 | flashcar.seu-dominio.com |
| Gartran | 8080 | gartran.seu-dominio.com |
| Outro | 8090 | outro.seu-dominio.com |

---

## 🔄 Workflow Deploy

### Arquivo: `.github/workflows/deploy.yml`

**O que acontece em cada step:**

1. **Checkout** — Clona o código
2. **Setup .NET** — Instala SDK 9.0
3. **Restore** — Restaura pacotes NuGet
4. **Build** — Compila API + Client
5. **Publish** — Gera binários otimizados
6. **Tests** — Roda E2E (continua mesmo se falhar)
7. **Create dirs** — SSH cria pastas na VPS
8. **SCP** — Copia arquivos via SSH
9. **Deploy script** — Executa `/scripts/deploy.sh`
10. **Health check** — Testa `/api/health`
11. **Log** — Registra resultado

---

## 🛠️ Script Deploy (VPS)

Localização: `scripts/deploy.sh`

**O que faz:**

1. Para serviço `gartran`
2. Backup da versão anterior em `/opt/gartran-backups/`
3. Copia novos arquivos para `/opt/gartran/`
4. Inicia serviço
5. Health check (30 tentativas)
6. Log em `/var/log/gartran/deploy.log`

**Rollback automático** (descomente se quiser):
```bash
# health_check
```
Quando descomentado, falha de health check triggers rollback automático.

---

## 🧪 Testando o Deploy

### 1. Localmente (antes de fazer push):
```bash
dotnet build PortalGartran.sln -c Release
dotnet publish PortalGartran.Server/PortalGartran.Server.csproj -c Release -o ./publish/api
dotnet test PortalGartran.Tests.E2E -c Release
```

### 2. SSH para VPS e verifique:
```bash
# Conectar
ssh ubuntu@<VPS_IP>

# Ver status do serviço
systemctl status gartran

# Ver logs
journalctl -u gartran -f

# Health check manual
curl http://localhost:8080/api/health
```

### 3. Após deploy, verifique:
```bash
# Último deploy log
cat /var/log/gartran/deploy.log

# Arquivos atuais
ls -lah /opt/gartran/

# Backups disponíveis
ls -lah /opt/gartran-backups/
```

---

## ⚠️ Troubleshooting

### Deploy falha: "Permission denied"
```bash
# Dar permissão SSH ao usuário
ssh-copy-id -i ~/.ssh/gartran_deploy ubuntu@<VPS_IP>
```

### Serviço não inicia após deploy
```bash
# Via SSH na VPS
journalctl -u gartran -n 50

# Testar manualmente
cd /opt/gartran
dotnet PortalGartran.Server.dll
```

### Health check falha
```bash
# Verificar se API está listening
netstat -tlnp | grep 8080
# ou
ss -tlnp | grep 8080

# Testar manualmente
curl -v http://localhost:8080/api/health
```

### Rollback manual
```bash
# Na VPS
sudo /tmp/gartran-deploy-*/scripts/deploy.sh
# Ou restaure do backup manualmente
cp -r /opt/gartran-backups/YYYYMMDD_HHMMSS/* /opt/gartran/
sudo systemctl restart gartran
```

---

## 📊 Monitoramento Contínuo

### Logs em tempo real:
```bash
ssh ubuntu@<VPS_IP> "journalctl -u gartran -f"
```

### Verificar saúde:
```bash
# Health check
curl -s http://localhost:8080/api/health | jq .

# Conexão DB (se expor endpoint)
curl -s http://localhost:8080/api/health/db | jq .
```

### Alertas (opcional):
Adicione ao seu Telegram/Slack:
```bash
# Monitorar serviço
systemd-watchdog check gartran

# Alertar se cair
systemctl set-property gartran OnFailure=send-alert.service
```

---

## 🔐 Checklist Pré-Deploy

Antes de fazer seu primeiro push:

- [ ] SSH key gerada e adicionada ao GitHub
- [ ] VPS secrets adicionados (VPS_HOST, VPS_USERNAME, VPS_SSH_KEY)
- [ ] Serviço `gartran` criado na VPS
- [ ] Porta 8080 liberada (ou a porta que usar)
- [ ] Diretório `/opt/gartran/` com permissões corretas
- [ ] PostgreSQL connection string correta em `appsettings.json`
- [ ] JWT secret diferente em produção
- [ ] CORS configurado apenas para domínios conhecidos
- [ ] Build local passa (`dotnet build`)
- [ ] Testes E2E passam (`dotnet test`)

---

## 📞 Support

Se algo quebrar:

1. Verifique logs: `journalctl -u gartran -f`
2. Verifique GitHub Actions: https://github.com/ahogler/gartran/actions
3. Teste manual na VPS: `curl http://localhost:8080/api/health`
4. Rollback se necessário: copie de `/opt/gartran-backups/`

---

**Deploy seguro e sem riscos aos outros projetos da VPS!** ✨
