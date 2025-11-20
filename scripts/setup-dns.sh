#!/bin/bash
set -e

# Get the external IP of the first ready node
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
TRAEFIK_HTTP_PORT=$(kubectl get svc traefik -n ingress -o jsonpath='{.spec.ports[?(@.name=="web")].nodePort}')
TRAEFIK_HTTPS_PORT=$(kubectl get svc traefik -n ingress -o jsonpath='{.spec.ports[?(@.name=="websecure")].nodePort}')

echo "Node IP: $NODE_IP"
echo "Traefik HTTP NodePort: $TRAEFIK_HTTP_PORT"
echo "Traefik HTTPS NodePort: $TRAEFIK_HTTPS_PORT"

# Create local DNS entry
echo "Adding local DNS entries..."

# Check if entries already exist
if ! grep -q "auth.a1-server.local" /etc/hosts 2>/dev/null; then
    echo "$NODE_IP auth.a1-server.local" | sudo tee -a /etc/hosts
    echo "Added auth.a1-server.local -> $NODE_IP"
else
    echo "DNS entry already exists for auth.a1-server.local"
fi

if ! grep -q "a1-server.local" /etc/hosts 2>/dev/null; then
    echo "$NODE_IP a1-server.local" | sudo tee -a /etc/hosts
    echo "Added a1-server.local -> $NODE_IP"
else
    echo "DNS entry already exists for a1-server.local"
fi

echo ""
echo "DNS Configuration Complete!"
echo "=========================="
echo "You can now access:"
echo "- Keycloak: http://auth.a1-server.local:$TRAEFIK_HTTP_PORT/auth/"
echo "- Keycloak Admin: http://auth.a1-server.local:$TRAEFIK_HTTP_PORT/auth/admin/"
echo "- Platform: http://a1-server.local:$TRAEFIK_HTTP_PORT/"
echo ""
echo "Note: HTTPS will be available once certificates are configured."