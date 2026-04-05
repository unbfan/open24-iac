output "instance_public_ip" {
  description = "Ephemeral IP (changes on stop/start — use elastic_ip instead)"
  value       = aws_instance.app.public_ip
}

output "elastic_ip" {
  description = "Static public IP — use this for DNS and SSH"
  value       = aws_eip.main.public_ip
}

output "DATABASE_CLIENT" {
  value = "postgres"
}

output "DATABASE_HOST" {
  value = aws_db_instance.pg.address
}

output "DATABASE_PORT" {
  value = aws_db_instance.pg.port
}

output "DATABASE_NAME" {
  value = aws_db_instance.pg.db_name
}

output "DATABASE_SSL" {
  value = true
}
