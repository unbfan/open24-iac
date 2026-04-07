variable "environment" {
  description = "Environment name (e.g. uat, prod, ephemeral-1). Used to prefix all resource names."
  type        = string
  default     = "uat"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ca-central-1"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 instance access"
  type        = string
}

variable "ec2_instance_type" {
  description = "EC2 instance type (t3.small ≈ DO s-2vcpu-2gb)"
  type        = string
  default     = "t3.small"
}

variable "rds_instance_class" {
  description = "RDS instance class (db.t4g.micro ≈ DO db-s-1vcpu-1gb)"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_password" {
  description = "PostgreSQL master password"
  type        = string
  sensitive   = true
}

variable "bff_domain" {
  description = "Domain name for open24-bff app"
  type        = string
}

variable "backend_domain" {
  description = "Domain name for open24-backend (Strapi)"
  type        = string
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt notifications"
  type        = string
}
