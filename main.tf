# Create a security group to enable communication between the JMeter Master and JMeter Slave EC2 instances
resource "aws_security_group" "sg-jmeter" {
  vpc_id      = aws_vpc.vpc.id
  name        = "jmeter-security-group"
  description = "Security group for EC2 instances"

  # Create inbound (ingress) and outbound (egress) rules within the security group

  dynamic "ingress" {
    for_each = var.inbound_rules

    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  dynamic "egress" {
    for_each = var.outbound_rules

    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
      description = egress.value.description
    }
  }
}

# Create an IAM role
resource "aws_iam_role" "example" {
  name = "example-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Create an IAM policy
resource "aws_iam_policy" "s3_policy" {
  name        = "s3-access-policy"
  description = "Policy for providing read-only access to S3"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.bucket.arn}/*"
    }
  ]
}
EOF
}

# Attach S3 policy to IAM role
resource "aws_iam_role_policy_attachment" "example_s3_fullaccess" {
  role       = aws_iam_role.example.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Associate IAM role with EC2 instance
resource "aws_iam_instance_profile" "example" {
  name = "example-instance-profile"
  role = aws_iam_role.example.name
}

# Define the local variables
locals {
  init_jmeter_master_script_path   = "./init-scripts/init-jmeter-master.tpl"
  init_jmeter_slave_script_path    = "./init-scripts/init-jmeter-slave.tpl"
  jmeter_master_public_ip_address  = aws_instance.jmeter_master.public_ip
  jmeter_master_private_ip_address = aws_instance.jmeter_master.private_ip

  # Convert the list of JMeter slave EC2 instances to a map with private IP as the key
  jmeter_slave_instances = {
    for idx, instance in aws_instance.jmeter_slave : instance.private_ip => {
      instance_id   = instance.id
      allocation_id = aws_eip.jmeter_slave-EIP[idx].id
    }
  }

  # Convert the map of JMeter slave EC2 instances to a comma-separated string of private IP addresses
  jmeter_slave_private_ip_addresses_str = join(",", keys(local.jmeter_slave_instances))

  # Alternatively, you can use the values of the map if needed (e.g., to get a list of EC2 instance objects)
  jmeter_slave_instances_list = values(local.jmeter_slave_instances)
}

# Create a bucket
resource "aws_s3_bucket" "bucket" {
  bucket        = "jmeter-bucket-${formatdate("YYYYMMDDHHmmss", timestamp())}" # The name of the bucket needs to be unique
  force_destroy = true

  tags = {
    Name = "jmeter-bucket"
  }
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "example" {
  depends_on = [aws_s3_bucket_ownership_controls.example]

  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}

# Upload the JMeter test script file to the S3 bucket
resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.bucket.id
  key    = "POC01_BBC_NavigateToHomepage_v01.jmx"                # Specify the desired key/name for the object in the S3 bucket
  source = "./test-scripts/POC01_BBC_NavigateToHomepage_v01.jmx" # Path to the test script file
}

# Define the template file for the JMeter Master EC2 instance
data "template_file" "init-jmeter-master" {
  template = file("${local.init_jmeter_master_script_path}")

  vars = {
    timestamp                             = timestamp()                     # Pass the timestamp value to the template
    filename                              = "Test_Result_$${timestamp}.jtl" # Use double $$ to escape the ${timestamp} placeholder
    aws_s3_bucket_id                      = aws_s3_bucket.bucket.id
    jmeter_slave_count                    = var.jmeter_slave_count
    jmeter_slave_private_ip_addresses_str = "${local.jmeter_slave_private_ip_addresses_str}"
  }
}

# Define the template file for the JMeter Slave EC2 instance
data "template_file" "init-jmeter-slave" {
  template = file("${local.init_jmeter_slave_script_path}")

  vars = {
    aws_s3_bucket_id = aws_s3_bucket.bucket.id
  }
}

# Create EC2 instances

# Specify the name and size of the EC2 instance for the JMeter Master
resource "aws_instance" "jmeter_master" {
  ami                         = data.aws_ami.ubuntu-linux-2204.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids      = [aws_security_group.sg-jmeter.id]
  associate_public_ip_address = var.ec2_associate_public_ip_address
  source_dest_check           = false
  key_name                    = aws_key_pair.key_pair.key_name
  iam_instance_profile        = aws_iam_instance_profile.example.name

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_s3_bucket.bucket]

  # Root disk
  root_block_device {
    volume_size           = var.ec2_root_volume_size
    volume_type           = var.ec2_root_volume_type
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name = "JMeter Master" # Add a name to the respective EC2 instance
  }

  # Specify what will happen on the EC2 instance once it has been created
  user_data = data.template_file.init-jmeter-master.rendered
}

# Create Elastic IP for the EC2 instance
resource "aws_eip" "jmeter_master-EIP" {
  provider = aws
  instance = aws_instance.jmeter_master.id
  tags = {
    Name = "jmeter_master-EIP"
  }
}

# Associate Elastic IP to Linux server
resource "aws_eip_association" "jmeter_master-EIP-Association" {
  instance_id   = aws_instance.jmeter_master.id
  allocation_id = aws_eip.jmeter_master-EIP.id
}

# Specify the name and size of the EC2 instance for the JMeter Slave
resource "aws_instance" "jmeter_slave" {
  count                       = var.jmeter_slave_count # Specify the number of JMeter slave EC2 instances to create
  ami                         = data.aws_ami.ubuntu-linux-2204.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public-subnet.id
  vpc_security_group_ids      = [aws_security_group.sg-jmeter.id]
  associate_public_ip_address = var.ec2_associate_public_ip_address
  source_dest_check           = false
  key_name                    = aws_key_pair.key_pair.key_name
  iam_instance_profile        = aws_iam_instance_profile.example.name

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_s3_bucket.bucket]

  # Root disk
  root_block_device {
    volume_size           = var.ec2_root_volume_size
    volume_type           = var.ec2_root_volume_type
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name = "JMeter-Slave-${count.index + 1}" # Add a unique name to the respective EC2 instance
  }

  # Specify what will happen on the EC2 instance once it has been created
  user_data = data.template_file.init-jmeter-slave.rendered
}

# Create Elastic IP for the EC2 instance
resource "aws_eip" "jmeter_slave-EIP" {
  count = var.jmeter_slave_count
  #provider = aws
  tags = {
    Name = "jmeter_slave-EIP-${count.index + 1}"
  }
}

# Associate Elastic IP to Linux server
resource "aws_eip_association" "jmeter_slave-EIP-Association" {
  count         = var.jmeter_slave_count
  instance_id   = element(aws_instance.jmeter_slave.*.id, count.index)
  allocation_id = element(aws_eip.jmeter_slave-EIP.*.id, count.index)
}
