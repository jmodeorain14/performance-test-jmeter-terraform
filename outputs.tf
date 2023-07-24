# Output the  number of slave EC2 instances that have been created
output "jmeter_slave_count" {
  value = var.jmeter_slave_count
}

# Output the private IP addresses of the JMeter slave EC2 instances
output "jmeter_slave_private_ip_addresses" {
  value = aws_instance.jmeter_slave.*.private_ip
}

# Output the Grafana Cloud instance URL
output "grafana_cloud_url" {
  value = grafana_cloud_stack.my_stack.url
}
