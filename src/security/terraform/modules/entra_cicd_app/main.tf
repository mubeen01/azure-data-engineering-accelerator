# App registration + service principal for external CI/CD (e.g. GitHub
# Actions deploying src/infrastructure/). Federated identity credential
# means GitHub authenticates via OIDC token exchange — no client secret is
# ever generated or stored, unlike a traditional service-principal password.
resource "azuread_application" "cicd" {
  display_name = var.app_display_name
}

resource "azuread_service_principal" "cicd" {
  client_id = azuread_application.cicd.client_id
}

resource "azuread_application_federated_identity_credential" "github_actions" {
  application_id = azuread_application.cicd.id
  display_name   = "github-actions-oidc"
  description    = "Allows GitHub Actions to authenticate as this app via OIDC — no stored secret."
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = var.github_federated_subject
}

# Scoped to the resource group src/infrastructure/ created, not the whole
# subscription — this identity deploys/updates this project's resources,
# nothing broader.
resource "azurerm_role_assignment" "cicd_contributor" {
  scope                = var.resource_group_id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.cicd.object_id
}
