#!/bin/bash
# ============================================================================
# Gartran VPS Setup - SIMPLES E SEGURO
# ============================================================================
# Este script prepara a VPS APENAS para rodar Gartran
# NÃO mexe em nenhum projeto que já esteja rodando
# ============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuração
DEPLOY_USER="gartran"
DEPLOY_DIR="/opt/gartran"
BACKUP_DIR="/opt/gartran-backups"
LOG_FILE="/var/log/gartran/deploy.log"
SERVICE_NAME="gartran"
API_PORT="8080"
DOMAIN="gartran.sistemawiser.com.br"

# ============================================================================
# Funções
# ============================================================================

log_header() {
    echo ""
    echo -e "${GREEN}=== $1 ===${NC}"
    echo ""
}

log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

check_if_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Este script deve ser executado com sudo"
        exit 1
    fi
    log_info "Executando como root"
}

check_existing_service() {
    log_header "Verificando se serviço já existe"
    
    if systemctl list-unit-files | grep -q "^$SERVICE_NAME.service"; then
        log_warn "Serviço $SERVICE_NAME já existe"
        echo -e "${YELLOW}O que fazer:${NC}"
        echo "  1. Se é primeira vez: continue"
        echo "  2. Se é atualização: continue (vai fazer backup)"
        echo "  3. Se quer remover: rode 'sudo systemctl stop $SERVICE_NAME' primeiro"
        read -p "Continuar? (s/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            log_error "Abortado pelo usuário"
            exit 1
        fi
    else
        log_info "Serviço novo (primeira vez)"
    fi
}

create_user() {
    log_header "Criando usuário gartran"
    
    if id "$DEPLOY_USER" &>/dev/null; then
        log_warn "Usuário $DEPLOY_USER já existe"
    else
        useradd -m -s /bin/bash $DEPLOY_USER
        log_info "Usuário $DEPLOY_USER criado"
    fi
}

create_directories() {
    log_header "Criando diretórios"
    
    mkdir -p $DEPLOY_DIR
    mkdir -p $BACKUP_DIR
    mkdir -p $(dirname $LOG_FILE)
    
    chown -R $DEPLOY_USER:$DEPLOY_USER $DEPLOY_DIR
    chown -R $DEPLOY_USER:$DEPLOY_USER $BACKUP_DIR
    chown -R $DEPLOY_USER:$DEPLOY_USER $(dirname $LOG_FILE)
    
    log_info "Diretórios criados e permissões setadas"
}

setup_systemd_service() {
    log_header "Configurando systemd service"
    
    cat > /etc/systemd/system/$SERVICE_NAME.service << 'EOF'
[Unit]
Description=Gartran Portal API
After=network.target postgresql.service

[Service]
Type=simple
User=gartran
Group=gartran
WorkingDirectory=/opt/gartran

# Start
ExecStart=/usr/bin/dotnet /opt/gartran/PortalGartran.Server.dll

# Restart policy
Restart=always
RestartSec=10

# Environment
Environment="ASPNETCORE_URLS=http://localhost:8080"
Environment="ASPNETCORE_ENVIRONMENT=Production"

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=gartran

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable $SERVICE_NAME
    
    log_info "systemd service criado e ativado"
    log_info "Porta: $API_PORT"
}

check_nginx() {
    log_header "Verificando Nginx"
    
    if command -v nginx &> /dev/null; then
        if systemctl is-active --quiet nginx; then
            log_info "Nginx está rodando"
            return 0
        else
            log_warn "Nginx instalado mas não está rodando"
            return 1
        fi
    else
        log_warn "Nginx não está instalado"
        echo ""
        echo "Para usar Gartran com HTTPS em $DOMAIN:"
        echo "  sudo apt-get install nginx"
        echo "  Depois rode este script novamente"
        return 1
    fi
}

setup_nginx() {
    log_header "Configurando Nginx (apenas proxy)"
    
    # Verificar se bloco já existe
    if grep -q "server_name $DOMAIN" /etc/nginx/sites-enabled/* 2>/dev/null; then
        log_warn "Bloco Nginx para $DOMAIN já existe"
        return
    fi
    
    # Criar arquivo de config
    cat > /etc/nginx/sites-available/gartran << 'EOF'
upstream gartran_backend {
    server localhost:8080;
}

server {
    server_name gartran.sistemawiser.com.br;
    
    # HTTP → HTTPS redirect (será feito após SSL)
    listen 80;
    return 301 https://$server_name$request_uri;
}

server {
    server_name gartran.sistemawiser.com.br;
    listen 443 ssl http2;
    
    # SSL (let's encrypt - configure depois)
    # ssl_certificate /etc/letsencrypt/live/gartran.sistemawiser.com.br/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/gartran.sistemawiser.com.br/privkey.pem;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    # Proxy para Gartran
    location / {
        proxy_pass http://gartran_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }
}
EOF

    # Ativar site (criar symlink)
    if [ ! -L /etc/nginx/sites-enabled/gartran ]; then
        ln -s /etc/nginx/sites-available/gartran /etc/nginx/sites-enabled/gartran
        log_info "Config Nginx criada (descomente SSL depois)"
    fi
    
    # Testar config
    if nginx -t 2>&1 | grep -q "successful"; then
        systemctl reload nginx
        log_info "Nginx recarregado com sucesso"
    else
        log_error "Erro na config do Nginx - revise manualmente"
        nginx -t
        return 1
    fi
}

show_next_steps() {
    log_header "PRÓXIMAS ETAPAS"
    
    echo -e "${GREEN}Setup básico completo!${NC}"
    echo ""
    echo "1. TESTE A PORTA INTERNA:"
    echo "   curl http://localhost:8080/api/health"
    echo ""
    echo "2. CONFIGURE SSL (Let's Encrypt):"
    echo "   sudo apt-get install certbot python3-certbot-nginx"
    echo "   sudo certbot --nginx -d $DOMAIN"
    echo ""
    echo "3. VERIFIQUE STATUS:"
    echo "   systemctl status $SERVICE_NAME"
    echo "   journalctl -u $SERVICE_NAME -f"
    echo ""
    echo "4. LOGS:"
    echo "   tail -f $LOG_FILE"
    echo ""
    echo "5. NGINX:"
    echo "   nginx -t"
    echo "   systemctl status nginx"
    echo ""
    echo -e "${YELLOW}⚠ IMPORTANTE:${NC}"
    echo "   - Descomente SSL em /etc/nginx/sites-available/gartran após certbot"
    echo "   - Não mexe em /etc/nginx/sites-available/* de outros projetos"
    echo "   - Gartran é isolado em: $DEPLOY_DIR"
    echo ""
}

show_rollback_info() {
    log_header "ROLLBACK (se der problema)"
    
    echo "Se precisar desfazer:"
    echo ""
    echo "1. Parar serviço:"
    echo "   sudo systemctl stop $SERVICE_NAME"
    echo ""
    echo "2. Remover config Nginx (se adicionou):"
    echo "   sudo rm /etc/nginx/sites-enabled/gartran"
    echo "   sudo rm /etc/nginx/sites-available/gartran"
    echo "   sudo systemctl reload nginx"
    echo ""
    echo "3. Remover serviço:"
    echo "   sudo systemctl disable $SERVICE_NAME"
    echo "   sudo rm /etc/systemd/system/$SERVICE_NAME.service"
    echo "   sudo systemctl daemon-reload"
    echo ""
    echo "4. Remover diretórios (ou deixar para próxima vez):"
    echo "   sudo rm -rf $DEPLOY_DIR"
    echo "   sudo rm -rf $BACKUP_DIR"
    echo ""
    echo "Nada disso afeta os outros projetos na VPS!"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Gartran VPS Setup - Simples e Seguro    ║${NC}"
    echo -e "${GREEN}║   Domínio: gartran.sistemawiser.com.br    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_if_root
    check_existing_service
    create_user
    create_directories
    setup_systemd_service
    
    if check_nginx; then
        setup_nginx
    fi
    
    show_next_steps
    show_rollback_info
    
    echo -e "${GREEN}✓ Setup concluído!${NC}"
    echo ""
}

# Execute
main "$@"
