output "catalog_name" {
  value = databricks_catalog.this.name
}

output "schema_full_names" {
  value = { for s, r in databricks_schema.this : s => "${databricks_catalog.this.name}.${s}" }
}
