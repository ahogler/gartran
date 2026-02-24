#!/bin/bash
set -e

# Gartran Deployment Script
# This script safely deploys Gartran to the VPS
# Includes backup, health check, and rollback capability

DEPLOY_USER="gartran"
DEPLOY_DIR="/opt/gartran"
BACKUP_DIR="/opt/gartran-backups"
TEMP_DEPLOY="/tmp/gartran-deploy-$(date +%s)"
SERVICE_NAME="gartran"
API_PORT="8080"
LOG_FILE="/var/log/gartran/deploy.log"

echo "=== Gartran Deployment Started ===" >> $LOG_FILE
echo "Timestamp: $(date)" >> $LOG_FILE

# Function: Ensure directories exist
ensure_directories() {
  echo "Ensuring directories exist..."
  mkdir -p $DEPLOY_DIR
  mkdir -p $BACKUP_DIR
  mkdir -p $(dirname $LOG_FILE)
  chown -R $DEPLOY_USER:$DEPLOY_USER $DEPLOY_DIR
  chown -R $DEPLOY_USER:$DEPLOY_USER $BACKUP_DIR
}

# Function: Stop service
stop_service() {
  echo "Stopping $SERVICE_NAME service..."
  if systemctl is-active --quiet $SERVICE_NAME; then
    systemctl stop $SERVICE_NAME
    sleep 2
    echo "$SERVICE_NAME stopped"
  else
    echo "$SERVICE_NAME not running"
  fi
}

# Function: Backup current deployment
backup_current() {
  if [ -d "$DEPLOY_DIR/api" ]; then
    BACKUP_TS=$(date +%Y%m%d_%H%M%S)
    echo "Backing up current deployment to $BACKUP_DIR/$BACKUP_TS..."
    mkdir -p $BACKUP_DIR/$BACKUP_TS
    cp -r $DEPLOY_DIR/api $BACKUP_DIR/$BACKUP_TS/ 2>/dev/null || true
    cp -r $DEPLOY_DIR/wasm $BACKUP_DIR/$BACKUP_TS/ 2>/dev/null || true
    echo "Backup complete: $BACKUP_DIR/$BACKUP_TS"
  fi
}

# Function: Deploy new files
deploy_files() {
  echo "Deploying new files..."
  
  # Copy API build
  if [ -d "$TEMP_DEPLOY/publish/api" ]; then
    cp -r $TEMP_DEPLOY/publish/api/* $DEPLOY_DIR/
    echo "API deployed"
  else
    echo "ERROR: API build not found in $TEMP_DEPLOY/publish/api"
    exit 1
  fi
  
  # Copy WASM client (optional, if served separately)
  if [ -d "$TEMP_DEPLOY/publish/wasm" ]; then
    mkdir -p $DEPLOY_DIR/wwwroot
    cp -r $TEMP_DEPLOY/publish/wasm/wwwroot/* $DEPLOY_DIR/wwwroot/
    echo "Blazor WASM deployed to wwwroot"
  fi
  
  # Set permissions
  chown -R $DEPLOY_USER:$DEPLOY_USER $DEPLOY_DIR
  chmod +x $DEPLOY_DIR/PortalGartran.Server || true
  
  echo "Files deployed successfully"
}

# Function: Start service
start_service() {
  echo "Starting $SERVICE_NAME service..."
  systemctl start $SERVICE_NAME
  sleep 3
  
  if systemctl is-active --quiet $SERVICE_NAME; then
    echo "$SERVICE_NAME started successfully"
  else
    echo "ERROR: $SERVICE_NAME failed to start"
    echo "Service status:" >> $LOG_FILE
    systemctl status $SERVICE_NAME >> $LOG_FILE 2>&1 || true
    exit 1
  fi
}

# Function: Health check
health_check() {
  echo "Performing health check..."
  
  for i in {1..30}; do
    if curl -f -s http://localhost:$API_PORT/api/health > /dev/null 2>&1; then
      echo "Health check PASSED"
      return 0
    fi
    
    if [ $i -lt 30 ]; then
      echo "Health check attempt $i/30 - retrying in 2 seconds..."
      sleep 2
    fi
  done
  
  echo "ERROR: Health check FAILED after 30 attempts"
  echo "Health check failed at $(date)" >> $LOG_FILE
  
  # Optional: Rollback on health check failure
  # Uncomment to enable automatic rollback
  # rollback
  
  exit 1
}

# Function: Rollback to previous deployment
rollback() {
  echo "WARNING: Initiating rollback..."
  
  latest_backup=$(ls -td $BACKUP_DIR/* 2>/dev/null | head -1)
  
  if [ -z "$latest_backup" ]; then
    echo "ERROR: No backup found for rollback"
    exit 1
  fi
  
  echo "Rolling back to $latest_backup..."
  stop_service
  
  rm -rf $DEPLOY_DIR/api 2>/dev/null || true
  rm -rf $DEPLOY_DIR/wasm 2>/dev/null || true
  
  cp -r $latest_backup/api $DEPLOY_DIR/ 2>/dev/null || true
  cp -r $latest_backup/wasm $DEPLOY_DIR/ 2>/dev/null || true
  
  chown -R $DEPLOY_USER:$DEPLOY_USER $DEPLOY_DIR
  
  start_service
  health_check
  
  echo "Rollback completed"
}

# Function: Cleanup
cleanup() {
  echo "Cleaning up temporary files..."
  rm -rf $TEMP_DEPLOY
  echo "Cleanup complete"
}

# Main execution
main() {
  ensure_directories
  stop_service
  backup_current
  
  # Note: Files should already be in /root/tmp/gartran-deploy
  # from the GitHub Actions scp-action
  if [ -d "/root/tmp/gartran-deploy" ]; then
    TEMP_DEPLOY="/root/tmp/gartran-deploy"
  fi
  
  deploy_files
  start_service
  
  # Uncomment health_check to enforce it (will rollback on failure if enabled)
  # health_check
  
  cleanup
  
  echo "=== Deployment Completed Successfully ===" >> $LOG_FILE
  echo "Timestamp: $(date)" >> $LOG_FILE
  echo ""
  echo "✅ Gartran deployed successfully"
  echo "Service: $SERVICE_NAME"
  echo "Port: $API_PORT"
  echo "Directory: $DEPLOY_DIR"
  echo ""
  echo "To view logs: journalctl -u $SERVICE_NAME -f"
}

# Execute main function
main "$@"
