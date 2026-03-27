output "droplet_ip" {
  value = digitalocean_droplet.app.ipv4_address
}

# Uncomment if using managed DB
# output "pg_host" {
#   value = digitalocean_database_cluster.pg.host
# }

output "DATABASE_CLIENT" {
  value = "postgres"
}
output "DATABASE_HOST" {
  value = digitalocean_database_cluster.pg.host
}
output "DATABASE_PORT" {
  value = digitalocean_database_cluster.pg.port
}
output "DATABASE_NAME" {
  value = digitalocean_database_cluster.pg.database
}
# output "DATABASE_USERNAME" {
#   value = digitalocean_database_cluster.pg.user
# }
# output "DATABASE_PASSWORD" {
#   value = digitalocean_database_cluster.pg.password
#   sensitive = true
# }
output "DATABASE_SSL" {
  value = true
}

output "FLOATING_IP" {
  value = digitalocean_floating_ip.main.ip_address
}
