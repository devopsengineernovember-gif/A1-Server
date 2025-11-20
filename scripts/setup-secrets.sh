#!/bin/bash
set -e

echo "Setting up A2 stack secrets..."

# Generate secure random values
ADMIN_PASSWORD=$(openssl rand -base64 24)
POSTGRES_PASSWORD=$(openssl rand -base64 24)
USER_PASSWORD=$(openssl rand -base64 24)
JWT_SECRET=$(openssl rand -base64 32)
SESSION_SECRET=$(openssl rand -base64 32)
ENCRYPTION_KEY=$(openssl rand -base64 32 | head -c 32)
CLIENT_SECRET_1=$(openssl rand -base64 24)
CLIENT_SECRET_2=$(openssl rand -base64 24)
CLIENT_SECRET_3=$(openssl rand -base64 24)
API_KEY=$(openssl rand -base64 24)
REDIS_PASSWORD=$(openssl rand -base64 24)
LDAP_PASSWORD=$(openssl rand -base64 24)

echo "Generated secure secrets..."

# Create Keycloak admin secret
kubectl create secret generic keycloak-admin-secret -n auth \
  --from-literal=password="$ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Keycloak postgres secret
kubectl create secret generic keycloak-postgres-secret -n auth \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=user-password="$USER_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Keycloak OIDC clients secret
kubectl create secret generic keycloak-oidc-clients -n auth \
  --from-literal=mcp-auth-client-id="mcp-auth" \
  --from-literal=mcp-auth-client-secret="$CLIENT_SECRET_1" \
  --from-literal=traefik-client-id="traefik" \
  --from-literal=traefik-client-secret="$CLIENT_SECRET_2" \
  --from-literal=grafana-client-id="grafana" \
  --from-literal=grafana-client-secret="$CLIENT_SECRET_3" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create MCP Edge config secret
kubectl create secret generic mcp-edge-config -n ingress \
  --from-literal=jwt-secret="$JWT_SECRET" \
  --from-literal=api-key="$API_KEY" \
  --from-literal=redis-url="redis://redis.auth.svc.cluster.local:6379" \
  --from-literal=postgres-url="postgresql://keycloak:$USER_PASSWORD@keycloak-postgresql.auth.svc.cluster.local:5432/keycloak" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create MCP Auth config secret
kubectl create secret generic mcp-auth-config -n auth \
  --from-literal=keycloak-client-id="mcp-auth" \
  --from-literal=keycloak-client-secret="$CLIENT_SECRET_1" \
  --from-literal=jwt-secret="$JWT_SECRET" \
  --from-literal=redis-url="redis://redis.auth.svc.cluster.local:6379" \
  --from-literal=postgres-url="postgresql://keycloak:$USER_PASSWORD@keycloak-postgresql.auth.svc.cluster.local:5432/keycloak" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create MCP Session config secret
kubectl create secret generic mcp-session-config -n auth \
  --from-literal=redis-url="redis://redis.auth.svc.cluster.local:6379" \
  --from-literal=redis-password="$REDIS_PASSWORD" \
  --from-literal=session-secret="$SESSION_SECRET" \
  --from-literal=encryption-key="$ENCRYPTION_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

# Create MCP Identity Map config secret
kubectl create secret generic mcp-identity-map-config -n auth \
  --from-literal=ldap-url="ldaps://ldap.a1-server.local:636" \
  --from-literal=ldap-bind-dn="cn=service,ou=users,dc=a1-server,dc=local" \
  --from-literal=ldap-bind-password="$LDAP_PASSWORD" \
  --from-literal=ldap-base-dn="ou=users,dc=a1-server,dc=local" \
  --from-literal=cache-ttl="300" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "All secrets created successfully!"
echo ""
echo "Important: Save these credentials securely:"
echo "=========================================="
echo "Keycloak Admin Password: $ADMIN_PASSWORD"
echo "PostgreSQL Password: $POSTGRES_PASSWORD"
echo "MCP Auth Client Secret: $CLIENT_SECRET_1"
echo "Traefik Client Secret: $CLIENT_SECRET_2"
echo "Grafana Client Secret: $CLIENT_SECRET_3"
echo "JWT Secret: $JWT_SECRET"
echo "Redis Password: $REDIS_PASSWORD"
echo "LDAP Service Password: $LDAP_PASSWORD"
echo "=========================================="