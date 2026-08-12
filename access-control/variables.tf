variable "databricks_workspace_url" {
  description = "Workspace URL output by infrastructure/envs/prod (module.workspace.workspace_url)"
  type        = string
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "manage_groups_locally" {
  description = "See access-control/modules/groups. Default false: groups come from SCIM."
  type        = bool
  default     = false
}
