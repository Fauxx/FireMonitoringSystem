output "zone_name_servers" {
  value = length(google_dns_managed_zone.main) > 0 ? google_dns_managed_zone.main[0].name_servers : []
}
