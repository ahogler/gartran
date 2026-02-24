# ✅ Checklist Deploy Gartran

**Siga na ordem. Não pule passos.**

---

## FASE 1: Preparação Local (Seu PC)

- [ ] **1.1** Git pull das mudanças
  ```bash
  cd seu-repo-gartran
  git pull origin master
  ```

- [ ] **1.2** Build local passa
  ```bash
  dotnet build PortalGartran.sln -c Release
  ```

- [ ] **1.3** Testes passam
  ```bash
  dotnet test PortalGartran.Tests.E2E -c Release
  ```

- [ ] **1.4** Gerar SSH key (se não tiver)
  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/gartran_deploy -C "gartran"
  # Deixe passphrase VAZIA
  ```

- [ ] **1.5** Copiar chave privada
  ```bash
  cat ~/.ssh/gartran_deploy
  # SALVE ISTO EM LUGAR SEGURO
  ```

---

## FASE 2: GitHub Secrets (GitHub.com)

- [ ] **2.1** Ir para: https://github.com/SEU-USER/gartran/settings/secrets/actions

- [ ] **2.2** Adicionar `VPS_HOST`
  - Name: `VPS_HOST`
  - Value: `seu-vps-ip` (ex: `123.456.789.100`)

- [ ] **2.3** Adicionar `VPS_USERNAME`
  - Name: `VPS_USERNAME`
  - Value: `ubuntu` (ou qual user tem acesso SSH)

- [ ] **2.4** Adicionar `VPS_SSH_KEY`
  - Name: `VPS_SSH_KEY`
  - Value: Conteúdo completo de `~/.ssh/gartran_deploy`
  - ⚠️ SEM COMEÇAR COM `-----BEGIN`... (se tiver, copie tudo mesmo)

---

## FASE 3: VPS Setup (Sua VPS Hostinger)

**⚠️ IMPORTANTE: Faça isto com cuidado e sem pressa**

- [ ] **3.1** SSH para VPS
  ```bash
  ssh ubuntu@seu-vps-ip
  ```

- [ ] **3.2** Criar SSH authorized_keys (na VPS)
  ```bash
  mkdir -p ~/.ssh
  nano ~/.ssh/authorized_keys
  # Cole sua chave pública (cat ~/.ssh/gartran_deploy.pub no seu PC)
  # Salve: Ctrl+X → Y → Enter
  chmod 600 ~/.ssh/authorized_keys
  ```

- [ ] **3.3** Testar SSH (na sua máquina)
  ```bash
  ssh -i ~/.ssh/gartran_deploy ubuntu@seu-vps-ip
  # Deve conectar SEM pedir senha
  exit
  ```

- [ ] **3.4** Copiar setup script (na sua máquina)
  ```bash
  scp -i ~/.ssh/gartran_deploy scripts/vps-setup-simple.sh ubuntu@seu-vps-ip:~
  ```

- [ ] **3.5** Rodar setup (na VPS)
  ```bash
  ssh -i ~/.ssh/gartran_deploy ubuntu@seu-vps-ip
  chmod +x vps-setup-simple.sh
  sudo bash vps-setup-simple.sh
  # Responda "s" em todas as perguntas
  exit
  ```

- [ ] **3.6** Instalar SSL (na VPS)
  ```bash
  ssh -i ~/.ssh/gartran_deploy ubuntu@seu-vps-ip
  sudo apt-get install certbot python3-certbot-nginx
  sudo certbot --nginx -d gartran.sistemawiser.com.br
  # Preencha email e siga as instruções
  exit
  ```

---

## FASE 4: Teste Manual (Antes de Automático)

- [ ] **4.1** Copiar build pra VPS (da sua máquina)
  ```bash
  mkdir -p publish-test
  cd seu-repo/PortalGartran.Server
  dotnet publish -c Release -o ../../publish-test
  cd ../../
  scp -i ~/.ssh/gartran_deploy -r publish-test/* ubuntu@seu-vps-ip:~/test-deploy/
  ```

- [ ] **4.2** Copiar pra local (na VPS)
  ```bash
  ssh -i ~/.ssh/gartran_deploy ubuntu@seu-vps-ip
  sudo cp -r ~/test-deploy/* /opt/gartran/
  sudo chown -R gartran:gartran /opt/gartran
  ```

- [ ] **4.3** Iniciar serviço (na VPS)
  ```bash
  sudo systemctl start gartran
  sudo systemctl status gartran
  # Deve mostrar: active (running)
  ```

- [ ] **4.4** Teste de health check (na VPS)
  ```bash
  curl http://localhost:8080/api/health
  # Deve retornar JSON com "status":"healthy"
  ```

- [ ] **4.5** Teste HTTPS (da sua máquina)
  ```bash
  curl -I https://gartran.sistemawiser.com.br/api/health
  # Deve retornar: HTTP/2 200
  ```

- [ ] **4.6** Verificar logs (na VPS)
  ```bash
  journalctl -u gartran -f
  # Ver logs de execução
  # Ctrl+C pra sair
  exit
  ```

---

## FASE 5: GitHub Actions (Automático)

- [ ] **5.1** Push pra disparar deploy (da sua máquina)
  ```bash
  cd seu-repo-gartran
  git add .
  git commit -m "Deploy Gartran pra VPS"
  git push origin master
  ```

- [ ] **5.2** Monitorar Actions
  - Ir em: https://github.com/SEU-USER/gartran/actions
  - Procurar "Deploy Gartran to VPS"
  - Esperar ficar verde (✓)

- [ ] **5.3** Verificar deploy (na VPS)
  ```bash
  ssh -i ~/.ssh/gartran_deploy ubuntu@seu-vps-ip
  sudo systemctl status gartran
  curl http://localhost:8080/api/health
  exit
  ```

---

## FASE 6: Validação Final

- [ ] **6.1** Seu app está online
  ```bash
  curl -I https://gartran.sistemawiser.com.br
  # Deve ser HTTP/2 200 ou 502 (se app não tá pronto)
  ```

- [ ] **6.2** Seus outros projetos continuam funcionando
  ```bash
  curl -I https://seu-outro-projeto.com
  # Deve funcionar como antes
  ```

- [ ] **6.3** Você sabe fazer rollback (emergência)
  ```bash
  # Se der problema:
  ssh -i ~/.ssh/gartran_deploy ubuntu@seu-vps-ip
  sudo systemctl stop gartran
  # Seus outros projetos continuam rodando!
  ```

- [ ] **6.4** Leia: `docs/VPS-SETUP-SEGURO.md`
  - Principalmente: seção "Rollback"
  - Salve o documento pra consultar depois

---

## 🎉 DONE!

Quando todos os checkboxes estão marcados, você tem:

✅ Gartran rodando em `https://gartran.sistemawiser.com.br`  
✅ Deploy automático via GitHub Actions  
✅ Isolado dos seus outros projetos  
✅ Backup automático antes de cada deploy  
✅ Rollback fácil em caso de problema  

---

## 🆘 Se Algo Quebrar

**Passo 1:** Parar Gartran
```bash
ssh -i ~/.ssh/gartran_deploy ubuntu@seu-vps-ip
sudo systemctl stop gartran
# Seus outros projetos continuam funcionando!
exit
```

**Passo 2:** Ver o erro
```bash
ssh -i ~/.ssh/gartran_deploy ubuntu@seu-vps-ip
journalctl -u gartran -n 100
# Copy/paste o erro
exit
```

**Passo 3:** Rollback
- Consulte: `docs/VPS-SETUP-SEGURO.md`
- Seção: "Rollback (Se Algo Quebrou)"

**Passo 4:** Me contactar com o erro

---

**Você consegue! Não é tão difícil quanto parece.** ✨
