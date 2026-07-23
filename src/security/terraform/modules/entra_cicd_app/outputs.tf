output "client_id" {
  description = "Set this, the tenant ID (root module's data.azurerm_client_config.current.tenant_id), and the subscription ID as AZURE_CLIENT_ID / AZURE_TENANT_ID / AZURE_SUBSCRIPTION_ID in a GitHub Actions workflow using azure/login@v2 — no client-secret input needed."
  value       = azuread_application.cicd.client_id
}
