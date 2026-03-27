provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_droplet" "app" {
  name     = "open24-app"
  size     = var.do_droplet_size
  region   = var.do_region
  image    = "docker-20-04"
  ssh_keys = [var.ssh_fingerprint]

  user_data = <<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1

echo "=== Starting user_data script ==="
start_time=$(date +%s)

# Wait for network and DNS to be ready
echo "Waiting for network and DNS to be ready..."
for attempt in $(seq 1 60); do
  if timeout 2 nslookup archive.ubuntu.com >/dev/null 2>&1; then
    echo "DNS ready after $attempt attempts"
    break
  fi
  if [ "$attempt" -eq 60 ]; then
    echo "DNS timeout, forcing static DNS..."
    # On Ubuntu 22.04 /etc/resolv.conf is a symlink managed by systemd-resolved.
    # Remove the symlink and write a real file so the change sticks.
    rm -f /etc/resolv.conf
    printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > /etc/resolv.conf

    # Also tell systemd-resolved to use these DNS servers
    mkdir -p /etc/systemd/resolved.conf.d
    printf '[Resolve]\nDNS=8.8.8.8 1.1.1.1\nFallbackDNS=9.9.9.9\n' \
      > /etc/systemd/resolved.conf.d/fallback.conf
    systemctl restart systemd-resolved 2>/dev/null || true
    sleep 5

    for retry in $(seq 1 10); do
      if timeout 2 nslookup archive.ubuntu.com >/dev/null 2>&1; then
        echo "DNS ready after static fallback on retry $retry"
        break
      fi
      sleep 3
    done
    break
  fi
  sleep 1
done
echo "Network and DNS are ready!"

# Retry apt-get update until it succeeds (network may still be settling)
echo "Running apt-get update..."
for i in $(seq 1 10); do
  apt-get update -y && break || {
    echo "apt-get update failed (attempt $i), retrying in 10s..."
    sleep 10
  }
done

# Create open24 user and SSH directory
echo "Creating open24 user..."
useradd -m -s /bin/bash open24 || true
echo "open24 ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/open24
chmod 440 /etc/sudoers.d/open24
mkdir -p /home/open24/.ssh
chmod 700 /home/open24/.ssh

if [ ! -f /home/open24/.ssh/authorized_keys ]; then
  cp /root/.ssh/authorized_keys /home/open24/.ssh/authorized_keys 2>/dev/null || touch /home/open24/.ssh/authorized_keys
  chmod 600 /home/open24/.ssh/authorized_keys
  chown -R open24:open24 /home/open24/.ssh
fi

# Install packages
echo "Installing dependencies..."
apt-get install -y --no-install-recommends curl nginx certbot python3-certbot-nginx ufw

# Install Node.js 22 LTS via NodeSource (includes npm)
echo "Installing Node.js 22 LTS..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
echo "Node $(node -v), npm $(npm -v)"

# Install pnpm and pm2
npm install -g pnpm pm2 --omit=dev 2>/dev/null || npm install -g pnpm pm2

# Setup backend .env  (use printf to avoid nested heredoc issues)
echo "Setting up backend config..."
mkdir -p /home/open24/do-config/open24-backend
printf '%s\n' \
  'DATABASE_CLIENT=postgres' \
  'DATABASE_HOST=${digitalocean_database_cluster.pg.host}' \
  'DATABASE_PORT=${digitalocean_database_cluster.pg.port}' \
  'DATABASE_NAME=${digitalocean_database_cluster.pg.database}' \
  'DATABASE_USERNAME=${digitalocean_database_cluster.pg.user}' \
  'DATABASE_PASSWORD=${digitalocean_database_cluster.pg.password}' \
  'DATABASE_SSL=true' \
  > /home/open24/do-config/open24-backend/.env
chown -R open24:open24 /home/open24/do-config/open24-backend

# Setup Nginx
echo "Configuring Nginx..."
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

# BFF (Nuxt — port 3000)
printf '%s\n' \
  'server {' \
  '    listen 80;' \
  '    server_name ${var.bff_domain};' \
  '    client_max_body_size 20M;' \
  '    location / {' \
  '        proxy_pass http://localhost:3000;' \
  '        proxy_http_version 1.1;' \
  '        proxy_set_header Upgrade $http_upgrade;' \
  '        proxy_set_header Connection "upgrade";' \
  '        proxy_set_header Host $host;' \
  '        proxy_set_header X-Real-IP $remote_addr;' \
  '        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' \
  '        proxy_set_header X-Forwarded-Proto $scheme;' \
  '        proxy_read_timeout 120s;' \
  '        proxy_connect_timeout 10s;' \
  '    }' \
  '}' \
  > /etc/nginx/sites-available/open24-bff

# Backend (Strapi — port 1337)
printf '%s\n' \
  'server {' \
  '    listen 80;' \
  '    server_name ${var.backend_domain};' \
  '    client_max_body_size 100M;' \
  '    location / {' \
  '        proxy_pass http://localhost:1337;' \
  '        proxy_http_version 1.1;' \
  '        proxy_set_header Upgrade $http_upgrade;' \
  '        proxy_set_header Connection "upgrade";' \
  '        proxy_set_header Host $host;' \
  '        proxy_set_header X-Real-IP $remote_addr;' \
  '        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' \
  '        proxy_set_header X-Forwarded-Proto $scheme;' \
  '        proxy_read_timeout 300s;' \
  '        proxy_connect_timeout 10s;' \
  '    }' \
  '}' \
  > /etc/nginx/sites-available/open24-backend

rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/test-github-action-2
ln -sf /etc/nginx/sites-available/open24-bff     /etc/nginx/sites-enabled/open24-bff
ln -sf /etc/nginx/sites-available/open24-backend /etc/nginx/sites-enabled/open24-backend
nginx -t && systemctl start nginx && systemctl enable nginx || echo "Nginx start failed"

# Firewall all
echo "Configuring firewall..."
ufw allow 22/tcp || true
ufw allow 80/tcp || true
ufw allow 443/tcp || true
ufw --force enable || true

# SSL cert
echo "Attempting SSL certificate setup..."
certbot --nginx -d ${var.bff_domain} -d ${var.backend_domain} --non-interactive --agree-tos -m ${var.letsencrypt_email} 2>/dev/null || echo "Certbot deferred"
systemctl reload nginx 2>/dev/null || true

# PM2 startup
echo "Setting up PM2..."
sudo -u open24 pm2 startup systemd -u open24 --hp /home/open24 2>/dev/null || true

end_time=$(date +%s)
duration=$((end_time - start_time))
echo "=== user_data script completed in $duration seconds ==="
EOF
}

# DigitalOcean Managed PostgreSQL v18
resource "digitalocean_database_cluster" "pg" {
  name       = "open24-pg"
  engine     = "pg"
  version    = "18"
  size       = "db-s-1vcpu-1gb"
  region     = var.do_region
  node_count = 1
}

resource "digitalocean_floating_ip" "main" {
  region = var.do_region
}

resource "digitalocean_floating_ip_assignment" "main" {
  ip_address = digitalocean_floating_ip.main.ip_address
  droplet_id = digitalocean_droplet.app.id
}

resource "digitalocean_firewall" "app" {
  name        = "open24-app-firewall"
  droplet_ids = [digitalocean_droplet.app.id]

  # Inbound rules
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Outbound rule (allow all)
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
