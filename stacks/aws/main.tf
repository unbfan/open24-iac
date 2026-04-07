provider "aws" {
  region = var.aws_region
}

# ──────────────────────────────────────────────
# Data sources
# ──────────────────────────────────────────────

# Latest Ubuntu 22.04 LTS AMI (amd64, HVM, EBS)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# ──────────────────────────────────────────────
# Networking (VPC, subnet, IGW, route table)
# ──────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "open24-${var.environment}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "open24-${var.environment}-igw" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "open24-${var.environment}-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags                    = { Name = "open24-${var.environment}-public-b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "open24-${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ──────────────────────────────────────────────
# Security Groups
# ──────────────────────────────────────────────

resource "aws_security_group" "app" {
  name        = "open24-${var.environment}-app-sg"
  description = "Allow SSH, HTTP, HTTPS inbound; all outbound"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "open24-${var.environment}-app-sg" }
}

resource "aws_security_group" "db" {
  name        = "open24-${var.environment}-db-sg"
  description = "Allow PostgreSQL from app SG only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "open24-${var.environment}-db-sg" }
}

# ──────────────────────────────────────────────
# SSH Key Pair
# ──────────────────────────────────────────────

resource "aws_key_pair" "deploy" {
  key_name   = "open24-${var.environment}-deploy"
  public_key = var.ssh_public_key
}

# ──────────────────────────────────────────────
# EC2 Instance (equivalent to DO s-2vcpu-2gb)
# ──────────────────────────────────────────────

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.ec2_instance_type
  key_name               = aws_key_pair.deploy.key_name
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.app.id]

  root_block_device {
    volume_size = 50
    volume_type = "gp3"
  }

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
    rm -f /etc/resolv.conf
    printf 'nameserver 8.8.8.8\nnameserver 1.1.1.1\n' > /etc/resolv.conf
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

# Retry apt-get update until it succeeds
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
  cp /home/ubuntu/.ssh/authorized_keys /home/open24/.ssh/authorized_keys 2>/dev/null || \
  cp /root/.ssh/authorized_keys /home/open24/.ssh/authorized_keys 2>/dev/null || \
  touch /home/open24/.ssh/authorized_keys
  chmod 600 /home/open24/.ssh/authorized_keys
  chown -R open24:open24 /home/open24/.ssh
fi

# Install packages
echo "Installing dependencies..."
apt-get install -y --no-install-recommends curl nginx certbot python3-certbot-nginx

# Install Node.js 22 LTS via NodeSource
echo "Installing Node.js 22 LTS..."
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
echo "Node $(node -v), npm $(npm -v)"

# Install pnpm and pm2
npm install -g pnpm pm2 --omit=dev 2>/dev/null || npm install -g pnpm pm2

# Setup backend .env
echo "Setting up backend config..."
mkdir -p /home/open24/do-config/open24-backend
printf '%s\n' \
  'DATABASE_CLIENT=postgres' \
  'DATABASE_HOST=${aws_db_instance.pg.address}' \
  'DATABASE_PORT=${aws_db_instance.pg.port}' \
  'DATABASE_NAME=${aws_db_instance.pg.db_name}' \
  'DATABASE_USERNAME=${aws_db_instance.pg.username}' \
  'DATABASE_PASSWORD=${var.db_password}' \
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
ln -sf /etc/nginx/sites-available/open24-bff     /etc/nginx/sites-enabled/open24-bff
ln -sf /etc/nginx/sites-available/open24-backend /etc/nginx/sites-enabled/open24-backend
nginx -t && systemctl start nginx && systemctl enable nginx || echo "Nginx start failed"

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

  tags = { Name = "open24-${var.environment}-app" }

  lifecycle {
    ignore_changes = [public_ip, associate_public_ip_address]
  }
}

# ──────────────────────────────────────────────
# Elastic IP (equivalent to DO Floating IP)
# ──────────────────────────────────────────────

resource "aws_eip" "main" {
  domain = "vpc"
  tags   = { Name = "open24-${var.environment}-eip" }
}

resource "aws_eip_association" "main" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.main.id
}

# ──────────────────────────────────────────────
# RDS PostgreSQL (equivalent to DO Managed PG)
# ──────────────────────────────────────────────

resource "aws_db_subnet_group" "pg" {
  name       = "open24-${var.environment}-pg-subnet"
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  tags       = { Name = "open24-${var.environment}-pg-subnet" }
}

resource "aws_db_instance" "pg" {
  identifier     = "open24-${var.environment}-pg"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.rds_instance_class

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"

  db_name  = "open24_${var.environment}"
  username = "open24"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.pg.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  skip_final_snapshot    = var.environment == "prod" ? false : true

  backup_retention_period = var.environment == "prod" ? 7 : 0
  multi_az                = false

  tags = { Name = "open24-${var.environment}-pg" }

  lifecycle {
    prevent_destroy = true
  }
}
