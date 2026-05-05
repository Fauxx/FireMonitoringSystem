#!/bin/bash

# Fire Monitoring Web Application - Setup Script
# Run this script after uploading code to your server

set -e

echo "🔥 Fire Monitoring Web Application - Setup Script"
echo "=================================================="
echo ""

# Select container runtime (Docker or Podman)
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    CONTAINER_RUNTIME="docker"
    echo "✅ Docker with Compose is installed"
elif command -v podman &> /dev/null && podman compose version &> /dev/null; then
    CONTAINER_RUNTIME="podman"
    echo "✅ Podman with Compose is installed"
elif command -v podman-compose &> /dev/null; then
    CONTAINER_RUNTIME="podman-compose"
    echo "✅ Podman Compose is installed"
else
    echo "❌ No supported container runtime found."
    echo "   Install one of:"
    echo "   - Docker Engine + Docker Compose plugin"
    echo "   - Podman + podman compose (or podman-compose)"
    exit 1
fi

run_compose() {
    if [ "${CONTAINER_RUNTIME}" = "docker" ]; then
        docker compose "$@"
    elif [ "${CONTAINER_RUNTIME}" = "podman" ]; then
        podman compose "$@"
    else
        podman-compose "$@"
    fi
}

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo ""
    echo "📝 Creating .env file..."
    
    # Generate random passwords
    POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-32)
    SESSION_SECRET=$(openssl rand -base64 32)
    
    cat > .env <<EOL
NODE_ENV=production
PORT=8000

DATABASE_URL=postgresql://fireuser:${POSTGRES_PASSWORD}@db:5432/fire_monitoring
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

SESSION_SECRET=${SESSION_SECRET}

GRAFANA_URL=http://grafana:3000
EOL
    
    echo "✅ .env file created with secure random passwords"
    echo ""
    echo "⚠️  Important: Save these credentials securely!"
    echo "   PostgreSQL Password: ${POSTGRES_PASSWORD}"
    echo ""
else
    echo "✅ .env file already exists"
fi

# Create required directories
echo "📁 Creating required directories..."
mkdir -p logs ssl
echo "✅ Directories created"

# Update nginx.conf with current hostname
echo ""
echo "🌐 Detecting server hostname..."
CURRENT_IP=$(curl -s http://checkip.amazonaws.com || echo "localhost")
echo "   Detected IP: ${CURRENT_IP}"

# Ask user for domain or IP
read -p "Enter your domain name or press Enter to use detected IP [${CURRENT_IP}]: " USER_DOMAIN
DOMAIN=${USER_DOMAIN:-$CURRENT_IP}

echo "   Using: ${DOMAIN}"

# Update nginx.conf
if grep -q "your-domain.com" nginx.conf; then
    sed -i "s/your-domain.com/${DOMAIN}/g" nginx.conf
    echo "✅ Updated nginx.conf with your domain/IP"
fi

# Pull container images
echo ""
echo "🐳 Pulling images..."
run_compose pull

# Build application
echo ""
echo "🔨 Building application..."
run_compose build

# Start services
echo ""
echo "🚀 Starting services..."
run_compose up -d

# Wait for services to be healthy
echo ""
echo "⏳ Waiting for services to be healthy..."
sleep 10

# Check service status
echo ""
echo "📊 Service Status:"
run_compose ps

echo ""
echo "=================================================="
echo "✅ Setup Complete!"
echo ""
echo "🌐 Your application should be accessible at:"
echo "   http://${DOMAIN}"
echo ""
echo "📝 Next Steps:"
echo "1. Create an admin user in the database"
echo "2. Configure Grafana dashboards"
echo "3. Set up SSL/HTTPS (recommended for production)"
echo ""
echo "📚 See DEPLOYMENT.md for detailed instructions"
echo "=================================================="
