# Configure the Grafana providers

provider "grafana" {
  alias         = "cloud"
  cloud_api_key = var.grafana_cloud_api_key
}

provider "grafana" {
  alias = "my_stack"

  url  = grafana_cloud_stack.my_stack.url
  auth = grafana_cloud_stack_service_account_token.cloud_sa.key
}
