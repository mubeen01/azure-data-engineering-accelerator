output "shared_identity_id" {
  value = module.shared_identity.id
}

output "shared_identity_client_id" {
  value = module.shared_identity.client_id
}

output "databricks_access_connector_id" {
  value = module.databricks_access_connector.id
}

output "cicd_app_client_id" {
  value = var.enable_cicd_app ? module.entra_cicd_app[0].client_id : null
}
