variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
}

variable "ssh_fingerprint" {
  description = "SSH key fingerprint for droplet access"
  type        = string
}

variable "do_droplet_size" {
  description = "Droplet size slug"
  type        = string
  default     = "s-2vcpu-2gb"
}

variable "do_region" {
  description = "DigitalOcean region"
  type        = string
  default     = "tor1"
}

variable "bff_domain" {
  description = "Domain name for open24-bff app (must point to droplet IP)"
  type        = string
}

variable "backend_domain" {
  description = "Domain name for open24-backend (Strapi) app — must be a 2nd-level subdomain (e.g. open24api.bbst.org) to be covered by Cloudflare wildcard SSL"
  type        = string
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt notifications"
  type        = string
}
