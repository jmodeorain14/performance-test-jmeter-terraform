# Output the number of JMeter worker EC2 instances that have been created
output "jmeter_worker_count" {
  value = var.jmeter_worker_count
}

# Output the private IP addresses of the JMeter worker EC2 instances
output "jmeter_worker_private_ip_addresses" {
  value = aws_instance.jmeter_worker.*.private_ip
}

# Output the Grafana Cloud instance URL
output "grafana_cloud_url" {
  value = grafana_cloud_stack.my_stack.url
}
