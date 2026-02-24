# 🪟 Windows 11 — Setup Gartran

**Este guia é só pra Windows 11. Se tiver Mac/Linux, vá pra DEPLOY-CHECKLIST.md**

---

## 🔧 Ferramentas Necessárias

Você precisa de **3 coisas** no Windows 11:

### 1. Git for Windows (com Git Bash)
- Download: https://git-scm.com/download/win
- Instale com **default settings**
- Vai incluir Git Bash (terminal Unix-like no Windows)

### 2. .NET 9 SDK
- Download: https://dotnet.microsoft.com/en-us/download/dotnet/9.0
- Instale a versão **9.0.x**
- Após instalar, abra PowerShell e verifique:
  ```powershell
  dotnet --version
  # Deve retornar: 9.0.x
  ```

### 3. OpenSSH Client (Nativo no Windows 11)
- Windows 11 já vem com OpenSSH integrado
- Verificar: **Settings → System → Optional features**
- Procure por "OpenSSH Client"
- Se não tiver, instale via Windows Package Manager:
  ```powershell
  # Abrir PowerShell como Admin, rodar:
  Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
  ```

---

## 🎯 Passo 1: Clonar Repositório (Windows)

```powershell
# Abrir PowerShell (ou Git Bash)
cd sua-pasta-de-projetos

# Clonar repo
git clone https://github.com/SEU-USER/gartran.git
cd gartran

# Verificar que está OK
git log --oneline -3
# Deve mostrar últimos 3 commits
```

---

## 🔐 Passo 2: Gerar SSH Key (Windows)

**IMPORTANTE:** Use **PowerShell como Admin** ou **Git Bash** (não CMD!)

### Opção A: PowerShell (Recomendado)

```powershell
# Abrir PowerShell como Admin
# Ir em: Settings → System → About → Advanced System Settings
# Ou: Win + X → Terminal (Admin)

# Criar pasta .ssh se não existir
New-Item -ItemType Directory -Force -Path $HOME\.ssh

# Gerar chave
ssh-keygen -t ed25519 -f $HOME\.ssh\gartran_deploy -C "gartran"

# Quando pedir passphrase: DEIXE VAZIO (apenas pressione Enter 2x)
```

### Opção B: Git Bash (Se PowerShell não funcionar)

```bash
# Abrir Git Bash (clique direito em pasta → "Git Bash Here")

# Gerar chave
ssh-keygen -t ed25519 -f ~/.ssh/gartran_deploy -C "gartran"

# Quando pedir passphrase: DEIXE VAZIO
```

---

## 📋 Passo 3: Copiar Chaves (Windows)

**Você vai precisar das 2 chaves:**

```powershell
# Private key (para GitHub Secret)
Get-Content $HOME\.ssh\gartran_deploy | Set-Clipboard
# Agora tá copiada na clipboard

# Ou abrir em editor:
notepad $HOME\.ssh\gartran_deploy
```

```powershell
# Public key (para VPS authorized_keys)
Get-Content $HOME\.ssh\gartran_deploy.pub | Set-Clipboard
# Agora tá copiada na clipboard

# Ou abrir em editor:
notepad $HOME\.ssh\gartran_deploy.pub
```

**SALVE AMBAS EM ARQUIVO SEGURO!**
- Crie um arquivo `SSH_KEYS_BACKUP.txt` em pasta protegida
- Cole o conteúdo das 2 chaves
- **Isso é seu backup se perder as chaves**

---

## 🌐 Passo 4: Adicionar ao SSH Agent (Windows)

O SSH Agent do Windows armazena sua chave para não precisar digitar senha:

```powershell
# Verificar se SSH Agent está rodando
Get-Service ssh-agent

# Se não tiver iniciado, inicie:
Start-Service ssh-agent

# Adicionar sua chave
ssh-add $HOME\.ssh\gartran_deploy

# Verificar que foi adicionada
ssh-add -l
# Deve listar sua chave ed25519
```

**Para SSH Agent iniciar automaticamente:**

```powershell
# Como Admin:
Set-Service ssh-agent -StartupType Automatic
```

---

## 🏗️ Passo 5: Testar SSH (Windows)

```powershell
# Testar conexão com VPS
ssh -i $HOME\.ssh\gartran_deploy ubuntu@seu-vps-ip

# Primeira vez vai pedir confirmação:
# The authenticity of host '...' can't be established.
# Type 'yes' to continue

# Digite: yes

# Se conectou SEM pedir senha, funcionou!
# Se pediu senha, algo errou com a chave
```

**Se der erro:**
```powershell
# Verificar permissões da chave
# No Windows, às vezes as permissões ficam erradas
# Solução:

# 1. Clique direito em: C:\Users\seu-usuario\.ssh\gartran_deploy
# 2. Properties → Security → Advanced
# 3. Remova herança e deixe apenas seu usuário com Full Control
# 4. Tente SSH novamente
```

---

## 💻 Passo 6: Build Local (Windows)

```powershell
# Na pasta do projeto
cd seu-repo-gartran

# Restaurar pacotes
dotnet restore PortalGartran.sln

# Build Release
dotnet build PortalGartran.sln -c Release

# Se tudo passou, você está OK!
```

---

## 🚀 Passo 7: GitHub Secrets (igual pra todos)

Ir em: https://github.com/SEU-USER/gartran/settings/secrets/actions

Adicionar 3 secrets (copy/paste do que copiou acima):

| Nome | Valor |
|------|-------|
| `VPS_HOST` | seu-vps-ip |
| `VPS_USERNAME` | ubuntu |
| `VPS_SSH_KEY` | Conteúdo completo de `gartran_deploy` |

---

## 🔗 Passo 8: Enviar Public Key pra VPS (Windows)

```powershell
# Copiou a public key? Cole em um arquivo temporário
# Ou copie direto via PowerShell:

# Criar arquivo temporário com a chave pública
$publicKey = Get-Content $HOME\.ssh\gartran_deploy.pub
$publicKey | Out-File -FilePath $HOME\public_key_temp.txt

# Agora você tem em: C:\Users\seu-usuario\public_key_temp.txt
# Copie e cole no ~/.ssh/authorized_keys da VPS

# Via SCP (se tiver SSH funcionando):
scp -i $HOME\.ssh\gartran_deploy $HOME\.ssh\gartran_deploy.pub ubuntu@seu-vps-ip:~
```

**Na VPS:**
```bash
# SSH para VPS
ssh -i ~/.ssh/gartran_deploy ubuntu@seu-vps-ip

# Na VPS:
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Adicionar sua chave pública
cat ~/gartran_deploy.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Testar
exit

# Do seu PC:
ssh -i $HOME\.ssh\gartran_deploy ubuntu@seu-vps-ip
# Deve conectar SEM pedir senha
```

---

## 📋 Passo 9: Copiar Scripts pra VPS (Windows)

```powershell
# Via SCP do seu PC
scp -i $HOME\.ssh\gartran_deploy scripts/vps-setup-simple.sh ubuntu@seu-vps-ip:~

# Verificar que foi copiado
ssh -i $HOME\.ssh\gartran_deploy ubuntu@seu-vps-ip "ls -la vps-setup-simple.sh"
```

---

## 🛠️ Passo 10: Rodar Setup na VPS

```powershell
# SSH para VPS
ssh -i $HOME\.ssh\gartran_deploy ubuntu@seu-vps-ip

# Na VPS:
chmod +x vps-setup-simple.sh
sudo bash vps-setup-simple.sh

# Responda as perguntas
# Quando terminar:
exit
```

---

## 🆘 Troubleshooting Windows 11

### "ssh command not found"
```powershell
# SSH não está no PATH
# Adicione: C:\Windows\System32\OpenSSH

# Ou use Git Bash que já vem com SSH
# Clique direito na pasta → "Git Bash Here"
```

### "Permission denied (publickey)"
```powershell
# Problema: SSH Agent não tá com a chave carregada

# Solução:
ssh-add $HOME\.ssh\gartran_deploy
ssh-add -l  # verificar que foi adicionada
```

### "WARNING: UNPROTECTED PRIVATE KEY FILE"
```powershell
# Problema: Permissões da chave estão erradas

# Solução:
# 1. Clique direito em C:\Users\seu-usuario\.ssh\gartran_deploy
# 2. Properties → Security → Advanced
# 3. Remova herança
# 4. Deixe apenas seu usuário com Full Control
# 5. Apply & OK
```

### "dotnet command not found"
```powershell
# .NET não foi instalado ou não está no PATH

# Solução:
# 1. Instale do https://dotnet.microsoft.com/en-us/download/dotnet/9.0
# 2. Feche PowerShell e abra uma nova aba (para recarregar PATH)
# 3. dotnet --version
```

### Git Bash vs PowerShell

Se uma coisa não funcionar em PowerShell, tente em **Git Bash:**

```bash
# Clique direito em pasta → "Git Bash Here"

# Depois use comandos bash normais:
ssh-keygen -t ed25519 -f ~/.ssh/gartran_deploy -C "gartran"
ssh -i ~/.ssh/gartran_deploy ubuntu@seu-vps-ip
scp -i ~/.ssh/gartran_deploy arquivo.txt ubuntu@seu-vps-ip:~
```

Git Bash é mais compatível com comandos Unix/Linux.

---

## 📝 Próximos Passos

Depois que fizer tudo acima:

1. **Verifique Build Local:**
   ```powershell
   dotnet build PortalGartran.sln -c Release
   ```

2. **Siga:** `DEPLOY-CHECKLIST.md` a partir da **Fase 2**
   - Você já fez Fase 1 (build local)
   - Pule SSH key setup (já fez)
   - Continue da Fase 2: GitHub Secrets

3. **Para coisas da VPS:**
   - Use PowerShell ou Git Bash para SSH
   - Tudo mais é igual

---

## ✨ Windows 11 Pro Tips

### Usar Git Bash como Terminal Padrão
Se preferir bash (mais parecido com Linux):
- Settings → System → About → Advanced System Settings
- Environment Variables → Path
- Adicione: `C:\Program Files\Git\bin`

Depois de rebootar, pode usar bash diretamente no PowerShell.

### Windows Terminal (Recomendado)
- Instale via Microsoft Store: "Windows Terminal"
- Muito melhor que PowerShell padrão
- Já vem com abas, cores, temas

### Salvar Comando SSH
Para não digitar toda hora:
```powershell
# Criar arquivo: C:\Users\seu-usuario\ssh-vps.ps1
"ssh -i $HOME\.ssh\gartran_deploy ubuntu@seu-vps-ip" | Out-File $HOME\ssh-vps.ps1

# Depois, apenas rode:
.\ssh-vps.ps1
```

---

**Pronto! Agora você está setup pra Windows 11.** 🎉

Próximo passo: **DEPLOY-CHECKLIST.md** começando da Fase 2.
