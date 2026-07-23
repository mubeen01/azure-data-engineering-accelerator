variable "app_display_name" {
  type        = string
  description = "Display name for the Entra ID app registration."
  default     = "adea-cicd"
}

variable "github_federated_subject" {
  type        = string
  description = "GitHub OIDC subject claim to trust, e.g. repo:my-org/my-repo:ref:refs/heads/main. See https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect for other subject patterns (environments, pull_request, tags)."
}

variable "resource_group_id" {
  type        = string
  description = "Resource group this identity is allowed to deploy into (the one src/infrastructure/ created)."
}
