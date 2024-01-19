# Step 1: Create a stack
resource "grafana_cloud_stack" "my_stack" {
  provider = grafana.cloud

  name        = "jmeterloadtesting"
  slug        = "jmeterloadtesting"
  region_slug = "eu"
}

# Step 2: Create a service account and key for the stack
resource "grafana_cloud_stack_service_account" "cloud_sa" {
  provider   = grafana.cloud
  stack_slug = grafana_cloud_stack.my_stack.slug

  name        = "cloud service account"
  role        = "Admin"
  is_disabled = false
}

resource "grafana_cloud_stack_service_account_token" "cloud_sa" {
  provider   = grafana.cloud
  stack_slug = grafana_cloud_stack.my_stack.slug

  name               = "terraform service account key"
  service_account_id = grafana_cloud_stack_service_account.cloud_sa.id
}

# Step 3: Create the required resources within the stack

# Create the folder
resource "grafana_folder" "my_folder" {
  provider = grafana.my_stack

  title = "Load Test Monitoring Dashboard"
}

# Create the dashboard
resource "grafana_dashboard" "dashboard" {
  provider = grafana.my_stack

  config_json = file("../grafana-dashboards/jmeter-dashboard.json")
  folder      = grafana_folder.my_folder.id
}

# Create the InfluxDB data source
resource "grafana_data_source" "influxdb" {
  provider = grafana.my_stack

  type               = "influxdb"
  name               = "InfluxDB"
  url                = "http://${aws_eip.jmeter_controller-EIP.public_ip}:8086" # Public IP address of the JMeter controller EC2 instance
  database_name      = "jmeter"
  basic_auth_enabled = false
  is_default         = false
}
