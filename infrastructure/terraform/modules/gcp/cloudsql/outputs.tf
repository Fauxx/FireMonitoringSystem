output "instance_connection_name" {
  description = "The connection name of the master instance to be used in connection strings"
  value       = google_sql_database_instance.main.connection_name
}

output "instance_ip_address" {
  description = "The IPv4 address of the master instance"
  value       = google_sql_database_instance.main.public_ip_address
}
