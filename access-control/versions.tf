terraform {
  required_version = ">= 1.5.0"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.50"
    }
  }

  backend "s3" {
    bucket         = "REPLACE-tfstate-bucket"
    key            = "access-control/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "REPLACE-tf-lock-table"
    encrypt        = true
  }
}

# Workspace-level provider (NOT accounts.cloud.databricks.com) - grants live in the workspace's
# Unity Catalog, so this points at the workspace URL created by infrastructure/envs/prod.
provider "databricks" {
  host = var.databricks_workspace_url
}
