# Declare the variables for the resources configured in main.tf

variable "inbound_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
}

variable "outbound_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
}

variable "jmeter_worker_count" {
  type        = number
  description = "Number of JMeter worker EC2 instances to create"
  default     = 1 # This can be changed during the "terraform apply" command, e.g. terraform apply -var "jmeter_worker_count=3"
}

variable "ec2_instance_type" {
  type        = string
  description = "EC2 instance type for the Ubuntu server"
  default     = "t2.medium"
}

variable "ec2_associate_public_ip_address" {
  type        = bool
  description = "Associate a public IP address to the EC2 instance"
  default     = true
}

variable "ec2_root_volume_size" {
  type        = number
  description = "Volume size of root volume of Ubuntu EC2 instance"
}

variable "ec2_data_volume_size" {
  type        = number
  description = "Volume size of data volume of Ubuntu EC2 instance"
}

variable "ec2_root_volume_type" {
  type        = string
  description = "Volume type of root volume of Ubuntu EC2 instance"
  default     = "gp2"
}

variable "ec2_data_volume_type" {
  type        = string
  description = "Volume type of data volume of Ubuntu EC2 instance"
  default     = "gp2"
}

variable "aws_s3_bucket_id" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "my_bucket_name"
}

# AWS access key
variable "aws_access_key" {
  type        = string
  description = "AWS access key"
}

# AWS secret key
variable "aws_secret_key" {
  type        = string
  description = "AWS secret key"
}

# AWS region
variable "aws_region" {
  type        = string
  description = "AWS region"
}
