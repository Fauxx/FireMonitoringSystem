# ==============================================================================
# CORE RESOURCES - AZURE DNS
# ==============================================================================

resource "azurerm_dns_zone" "this" {
  name                = var.dns_zone_name
  resource_group_name = var.resource_group_name
}

resource "azurerm_dns_a_record" "this" {
  for_each            = var.a_records
  name                = each.key
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = azurerm_dns_zone.this.resource_group_name
  ttl                 = 300
  records             = [each.value]
}
