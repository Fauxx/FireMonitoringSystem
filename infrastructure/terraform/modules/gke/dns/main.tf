resource "google_dns_managed_zone" "main" {
  count       = var.dns_zone_name != "" ? 1 : 0
  project     = var.project_id
  name        = replace(var.dns_zone_name, ".", "-")
  dns_name    = "${var.dns_zone_name}."
  description = "Managed zone for ${var.dns_zone_name}"
  visibility  = "public"
}

resource "google_dns_record_set" "a_records" {
  for_each = var.dns_zone_name != "" ? var.a_records : {}

  project      = var.project_id
  managed_zone = google_dns_managed_zone.main[0].name
  name         = each.key == "@" ? "${var.dns_zone_name}." : "${each.key}.${var.dns_zone_name}."
  type         = "A"
  ttl          = 300
  rrdatas      = [each.value]
}
