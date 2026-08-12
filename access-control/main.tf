# THE REUSABLE, SELF-SERVICE ENTRY POINT.
#
# Every *.yaml file under policies/domains/ becomes one governed catalog with grants driven
# entirely by that file's content. Onboarding a new domain team requires ZERO new Terraform code:
# add policies/domains/<domain>.yaml, open a PR, merge.

locals {
  domain_files = fileset("${path.module}/../policies/domains", "*.yaml")

  domains = {
    for f in local.domain_files :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/../policies/domains/${f}"))
  }

  # Every group name referenced across every domain, for the groups guardrail module.
  all_group_names = toset(flatten([
    for domain, cfg in local.domains : values(cfg.role_groups)
  ]))
}

module "groups" {
  source = "./modules/groups"

  group_names    = local.all_group_names
  manage_locally = var.manage_groups_locally
}

module "domain_catalog" {
  source   = "./modules/domain-catalog"
  for_each = local.domains

  domain_name = each.key
  environment = var.environment
  owner       = each.value.role_groups.workspace_admin
  role_groups = each.value.role_groups
  policy      = each.value.policy

  depends_on = [module.groups]
}

# The ONLY compute surface this platform exposes: one shared serverless SQL
# warehouse. Runs against the workspace-level provider (this root, unlike
# infrastructure/, applies AFTER the workspace exists).
module "serverless_warehouse" {
  source = "../infrastructure/modules/serverless-sql-warehouse"

  warehouse_name = "acme-${var.environment}-shared-warehouse"
}

# Per-domain CAN_USE / CAN_MANAGE on that shared warehouse, driven by the
# same role_groups each domain already defines for its catalog grants -
# zero extra config per domain team.
module "serverless_permissions" {
  source   = "./modules/serverless-permissions"
  for_each = local.domains

  warehouse_id = module.serverless_warehouse.warehouse_id
  role_groups  = each.value.role_groups
}
