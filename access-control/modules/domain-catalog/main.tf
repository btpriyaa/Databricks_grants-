# Reusable RBAC unit: one domain in, one governed catalog out.
#   - creates the catalog + medallion schemas
#   - fans policy (role -> schema -> privileges) out into Unity Catalog grants
#   - guardrails what privileges a domain policy file is even allowed to request
#
# Usage: see access-control/main.tf, which instantiates this once per file under
# policies/domains/*.yaml.

locals {
  catalog_name = "${var.domain_name}_${var.environment}"

  # Flatten every privilege referenced anywhere in the policy, for validation.
  all_privileges = distinct(flatten([
    for role, cfg in var.policy : flatten([for scope, privs in cfg : privs])
  ]))

  invalid_privileges = [
    for p in local.all_privileges : p if !contains(var.allowed_privileges, p)
  ]
}

# --- Guardrails -------------------------------------------------------------
# Fails `terraform plan` (not just apply) if a domain policy file requests a
# privilege outside the approved allow-list, or tries to self-grant ALL_PRIVILEGES.

check "no_disallowed_privileges" {
  assert {
    condition     = length(local.invalid_privileges) == 0
    error_message = "Domain '${var.domain_name}': policy contains privileges not on the approved allow-list: ${join(", ", local.invalid_privileges)}"
  }
}

check "no_all_privileges_from_domain_policy" {
  assert {
    condition = alltrue([
      for role, cfg in var.policy : !contains(try(cfg.catalog, []), "ALL_PRIVILEGES")
    ])
    error_message = "Domain '${var.domain_name}': domain policy files may not grant ALL_PRIVILEGES; that requires a platform-team-owned change."
  }
}

check "every_policy_role_has_a_group" {
  assert {
    condition = alltrue([
      for role, cfg in var.policy : contains(keys(var.role_groups), role)
    ])
    error_message = "Domain '${var.domain_name}': policy references a role with no entry in role_groups."
  }
}

# --- Catalog & schemas -------------------------------------------------------

resource "databricks_catalog" "this" {
  name    = local.catalog_name
  comment = "Domain catalog for '${var.domain_name}' (${var.environment}) - managed by access-control"
  owner   = var.owner

  properties = {
    domain      = var.domain_name
    environment = var.environment
    managed_by  = "terraform-access-control"
  }
}

resource "databricks_schema" "this" {
  for_each     = toset(var.schemas)
  catalog_name = databricks_catalog.this.name
  name         = each.value
  comment      = "${each.value} layer for ${var.domain_name}"
}

# --- Grants -------------------------------------------------------------
# One databricks_grants resource per securable, aggregating every role that
# has an entry for that securable. Re-running with an updated policy.yaml
# produces a clean diff of exactly what changed.

resource "databricks_grants" "catalog" {
  catalog = databricks_catalog.this.name

  dynamic "grant" {
    for_each = {
      for role, cfg in var.policy : role => cfg.catalog
      if try(cfg.catalog, null) != null
    }
    content {
      principal  = var.role_groups[grant.key]
      privileges = grant.value
    }
  }
}

resource "databricks_grants" "schema" {
  for_each = toset(var.schemas)
  schema   = "${databricks_catalog.this.name}.${each.value}"

  dynamic "grant" {
    for_each = {
      for role, cfg in var.policy : role => cfg[each.value]
      if try(cfg[each.value], null) != null
    }
    content {
      principal  = var.role_groups[grant.key]
      privileges = grant.value
    }
  }

  depends_on = [databricks_schema.this]
}
