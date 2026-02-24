# 🛡️ VPS Setup Gartran — SEGURO E ISOLADO

**⚠️ Leia isto antes de fazer qualquer coisa na VPS!**

---

## 🎯 Princípio: Isolamento Total

Gartran vai rodar **completamente isolado** dos seus outros projetos:

```
┌─────────────────────────────────────────┐
│          VPS Hostinger                  │
├─────────────────────────────────────────┤
│  Projeto 1  │  Projeto 2  │   Gartran   │
│  /opt/proj1 │  /opt/proj2 │  /opt/gartran
│  user1      │  user2      │  usergartran
│  service1   │  service2   │  servicegartran
│  :8000      │  :8001      │  :8080
└─────────────────────────────────────────┘
        Nginx (proxy reverso)
           porta 443/SSL
```

**Se algo der errado em Gartran, seus outros projetos NÃO são afetados.**

---

## ✅ Pré-requisitos

### Na sua máquina local:

```bash
# 1. Gerar SSH key (se não tiver)
ssh-keygen -t ed25519 -f ~/.ssh/gartran_deploy -C "gartran"
# Deixe passphrase VAZIA quando pedir

# 2. Ver conteúdo da chave privada
cat ~/.ssh/gartran_deploy

# COPIE ESTE CONTEÚDO → vai pro GitHub Secret
```

### Na VPS (via SSH):

```bash
ssh ubuntu@seu-vps-ip

# Ver se Nginx está rodando
sudo systemctl status nginx
# ou
sudo systemctl status apache2

# Confirmar que .NET 9 está instalado
dotnet --version
# Deve retornar: 9.0.x

# Ver quais projetos já estão rodando
sudo systemctl list-units --all | grep -E "(\.service|active)"
```

---

## 🚀 Passo 1: Preparar SSH Key na VPS

**Na VPS:**

```bash
# Login
ssh ubuntu@seu-vps-ip

# Criar diretório SSH (se não existir)
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Adicionar sua chave pública
nano ~/.ssh/authorized_keys
# Cole aqui o conteúdo de ~/.ssh/gartran_deploy.pub
# (se não tiver, rode ssh-keygen -y -f ~/.ssh/gartran_deploy > ~/.ssh/gartran_deploy.pub)

chmod 600 ~/.ssh/authorized_keys

# Testar conexão
exit

# Da sua máquina:
ssh -i ~/.ssh/gartran_deploy ubuntu@seu-vps-ip
# Deve conectar SEM pedir senha

# Copiar conteúdo da PRIVATE key pro GitHub Secret
cat ~/.ssh/gartran_deploy
```

**No GitHub:**

Adicione em **Settings → Secrets and variables → Actions**:

| Nome | Valor |
|------|-------|
| `VPS_HOST` | `seu-vps-ip` ou domínio |
| `VPS_USERNAME` | `ubuntu` (ou qual user seu na VPS) |
| `VPS_SSH_KEY` | Conteúdo completo de `~/.ssh/gartran_deploy` |

---

## 🛠️ Passo 2: Rodar Setup Script na VPS

**Na sua máquina local:**

```bash
# Clonar/verificar repo
cd seu-repo-gartran
git pull origin master

# Copiar script pra VPS
scp -i ~/.ssh/gartran_deploy scripts/vps-setup-simple.sh ubuntu@seu-vps-ip:~

# Conectar na VPS
ssh -i ~/.ssh/gartran_deploy ubuntu@seu-vps-ip
```

**Na VPS:**

```bash
# Tornar script executável
chmod +x vps-setup-simple.sh

# RODAR O SCRIPT (com sudo)
sudo bash vps-setup-simple.sh

# Responda as perguntas (sempre "s" na primeira vez)
```

**O script vai fazer:**

✅ Criar usuário `gartran`  
✅ Criar diretórios `/opt/gartran` + `/opt/gartran-backups`  
✅ Criar systemd service `gartran`  
✅ Configurar Nginx (se instalado)  
✅ Mostrar próximas etapas  

---

## 🔐 Passo 3: Configurar SSL (Let's Encrypt)

**Na VPS:**

```bash
# Instalar certbot
sudo apt-get install certbot python3-certbot-nginx

# Gerar certificado
sudo certbot --nginx -d gartran.sistemawiser.com.br

# Seguir as instruções:
# - Email: seu-email@example.com
# - Aceitar terms
# - Compartilhar email (escolha sim/não)
# - Escolher redirecionar HTTP → HTTPS (escolha 2)

# Verificar se funcionou
sudo nginx -t
# Deve retornar: successful

# Testar HTTPS
curl -I https://gartran.sistemawiser.com.br
# Deve retornar 502 (normal, ainda não tem app rodando)
```

---

## 🧪 Passo 4: Testar Deploy Manual (Antes de Automático)

Isso ajuda a encontrar problemas **antes** de fazer deploy automático.

```bash
# Na VPS, preparar diretório
mkdir -p ~/test-deploy
cd ~/test-deploy

# Copiar o build publicado (ou fazer build na VPS)
# Se tiver do seu PC:
scp -r seu-repo/publish/api/* ubuntu@seu-vps-ip:~/test-deploy/

# Na VPS:
cd ~/test-deploy

# Testar rodar o app
dotnet PortalGartran.Server.dll

# Deve ver algo como:
# info: Microsoft.Hosting.Lifetime[14]
#       Now listening on: http://localhost:5000
# (ou outra porta)

# CTRL+C para parar

# Se funcionou, copiar pros diretórios reais
sudo cp -r * /opt/gartran/
sudo chown -R gartran:gartran /opt/gartran

# Iniciar serviço
sudo systemctl start gartran

# Verificar status
sudo systemctl status gartran
# Deve mostrar: active (running)

# Testar health check
curl http://localhost:8080/api/health
# Deve retornar: {"status":"healthy",...}

# Testar HTTPS (do seu PC)
curl -I https://gartran.sistemawiser.com.br/api/health
# Deve retornar: HTTP/2 200
```

---

## 🤖 Passo 5: Configurar GitHub Actions (Automático)

Quando tudo tá funcionando manualmente, ativa o automático:

```bash
# No seu repo local
cd seu-repo-gartran

# Verificar que GitHub Actions está pronto
cat .github/workflows/deploy.yml
# Deve estar lá

# Fazer um push pra disparar deploy
git push origin master

# Monitorar em: https://github.com/SEU-USER/gartran/actions
# Vai ver: "Deploy Gartran to VPS"
```

**Quando o Actions completar:**

```bash
# Na VPS
sudo systemctl status gartran
# Deve estar running

# Ver logs do deploy
cat /var/log/gartran/deploy.log

# Ver logs da aplicação
journalctl -u gartran -f
# CTRL+C para sair
```

---

## ⚠️ Troubleshooting

### Erro: "Connection refused"
```bash
# Verificar se serviço está rodando
sudo systemctl status gartran

# Se não está:
sudo systemctl start gartran
sudo systemctl status gartran

# Ver erro detalhado
journalctl -u gartran -n 50
```

### Erro: "502 Bad Gateway" no Nginx
```bash
# Verificar se app está ouvindo em 8080
sudo ss -tlnp | grep 8080

# Se não está, o serviço pode ter crashado
journalctl -u gartran -n 100

# Tentar restart
sudo systemctl restart gartran
sleep 3
curl http://localhost:8080/api/health
```

### Erro: "No space left on device"
```bash
# Ver espaço em disco
df -h

# Ver diretório de backups
ls -lah /opt/gartran-backups/
# Se tiver muitos backups antigos:
sudo rm -rf /opt/gartran-backups/2024* # exemplo
```

### SSH Connection Error no GitHub Actions
```bash
# Verificar authorized_keys na VPS
cat ~/.ssh/authorized_keys
# Deve conter sua chave pública

# Testar conexão SSH local
ssh -i ~/.ssh/gartran_deploy -v ubuntu@seu-vps-ip
# Ver se conecta sem pedir senha
```

---

## 🔄 Rollback (Se Algo Quebrou)

### Opção 1: Parar Gartran (Rápido, ~1 minuto)
```bash
# Na VPS
sudo systemctl stop gartran

# Verificar se outros projetos ainda funcionam
curl https://seu-outro-projeto.com
# Deve funcionar

# Você tem tempo para investigar o problema
# Depois reinicia com:
sudo systemctl start gartran
```

### Opção 2: Reverter Para Backup Anterior
```bash
# Na VPS
sudo systemctl stop gartran

# Ver backups disponíveis
sudo ls -lah /opt/gartran-backups/

# Restaurar backup (ex: 20240224_152030)
sudo cp -r /opt/gartran-backups/20240224_152030/api/* /opt/gartran/
sudo chown -R gartran:gartran /opt/gartran

# Reiniciar
sudo systemctl start gartran

# Verificar
curl http://localhost:8080/api/health
```

### Opção 3: Remover Gartran Completamente (Se Não Quiser Mais)
```bash
# Na VPS
sudo systemctl stop gartran
sudo systemctl disable gartran
sudo rm /etc/systemd/system/gartran.service
sudo systemctl daemon-reload

# Remover Nginx config
sudo rm /etc/nginx/sites-enabled/gartran
sudo rm /etc/nginx/sites-available/gartran
sudo systemctl reload nginx

# Remover diretórios (CUIDADO!)
sudo rm -rf /opt/gartran
sudo rm -rf /opt/gartran-backups

# Certificado SSL (Let's Encrypt) continua instalado
# Se quiser remover:
sudo certbot delete --cert-name gartran.sistemawiser.com.br
```

**NADA disso afeta seus outros projetos!**

---

## 📊 Checklist Final

Antes de colocar em produção:

- [ ] SSH key criada e testada
- [ ] VPS secrets adicionados no GitHub
- [ ] Script `vps-setup-simple.sh` rodou com sucesso
- [ ] SSL (Let's Encrypt) funciona
- [ ] Deploy manual testado
- [ ] `curl http://localhost:8080/api/health` retorna OK
- [ ] `curl https://gartran.sistemawiser.com.br/api/health` retorna OK
- [ ] GitHub Actions push funcionou
- [ ] Seus outros projetos continuam funcionando
- [ ] Você sabe como fazer rollback (leia seção acima)

---

## 🆘 Precisa de Ajuda?

Se algo der errado:

1. **Parar Gartran** (não afeta outros):
   ```bash
   sudo systemctl stop gartran
   ```

2. **Verificar logs**:
   ```bash
   journalctl -u gartran -n 100
   ```

3. **Fazer rollback** (seção acima)

4. **Documentar o erro** e me mandar

**Relax — tá tudo isolado e seguro!** ✨
