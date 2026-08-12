variable "domain_name" {
  description = "Short domain identifier, e.g. 'marketing'. Used as the catalog name prefix."
  type        = string
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "owner" {
  description = "Principal (group name) that owns the catalog, typically the domain's workspace-admin-delegated group"
  type        = string
}

variable "schemas" {
  description = "Medallion layers to create in the catalog"
  type        = list(string)
  default     = ["bronze", "silver", "gold"]
}

variable "role_groups" {
  description = "Map of role key (e.g. 'data_engineer') -> Databricks/SCIM group display name for this domain"
  type        = map(string)
}

variable "policy" {
  description = <<-DESC
    Map of role key -> { catalog = [privileges], <schema_name> = [privileges], ... }
    Every key in role_groups may optionally appear here; a role with no matching key gets no grants.
  DESC
  type = any
}

variable "allowed_privileges" {
  description = "Allow-list enforced on every privilege used in var.policy (guardrail against scope creep)"
  type = list(string)
  default = [
    "USE_CATALOG", "USE_SCHEMA", "CREATE_SCHEMA", "CREATE_TABLE",
    "CREATE_VIEW", "CREATE_FUNCTION", "CREATE_MODEL", "MODIFY",
    "SELECT", "EXECUTE", "REFRESH",
  ]
}
