output "catalogs" {
  value = { for domain, mod in module.domain_catalog : domain => mod.catalog_name }
}
