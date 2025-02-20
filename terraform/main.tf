# Create a security group to enable communication between the JMeter controller and JMeter worker EC2 instances
resource "aws_security_group" "sg-jmeter" {
  vpc_id      = aws_vpc.vpc.id
  name        = "jmeter-security-group"
  description = "Security group for EC2 instances"

  # Create inbound (ingress) rules within the security group
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

  # Create outbound (egress) rules within the security group 
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
  # Paths to initalization scripts
  init_jmeter_controller_script_path = "../init-scripts/init-jmeter-controller.tpl"
  init_jmeter_worker_script_path     = "../init-scripts/init-jmeter-worker.tpl"

  # JMeter Controller IP addresses
  jmeter_controller_public_ip_address  = aws_instance.jmeter_controller.public_ip
  jmeter_controller_private_ip_address = aws_instance.jmeter_controller.private_ip

  # Convert the list of JMeter worker EC2 instances to a map with private IP as the key
  jmeter_worker_instances = {
    for idx, instance in aws_instance.jmeter_worker : instance.private_ip => {
      instance_id   = instance.id
      allocation_id = aws_eip.jmeter_worker-EIP[idx].id
    }
  }

  # Convert the map of JMeter worker EC2 instances to a comma-separated string of private IP addresses
  jmeter_worker_private_ip_addresses_str = join(",", keys(local.jmeter_worker_instances))

  # Alternatively, you can use the values of the map if needed (e.g., to get a list of EC2 instance objects)
  jmeter_worker_instances_list = values(local.jmeter_worker_instances)

  # Define the template content for the JMeter controller EC2 instance
  init_jmeter_controller = templatefile("${local.init_jmeter_controller_script_path}", {
    timestamp                              = timestamp()                      # Pass the timestamp value to the template
    filename                               = "Test_Result_${timestamp()}.jtl" # No need to escape with $${timestamp} in templatefile
    aws_s3_bucket_id                       = aws_s3_bucket.bucket.id
    jmeter_worker_count                    = var.jmeter_worker_count
    jmeter_worker_private_ip_addresses_str = local.jmeter_worker_private_ip_addresses_str
  })

  # Define the template content for the JMeter worker EC2 instance
  init_jmeter_worker = templatefile("${local.init_jmeter_worker_script_path}", {
    aws_s3_bucket_id = aws_s3_bucket.bucket.id
  })
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
  key    = "POC01_BBC_NavigateToHomepage_v02.jmx"                 # Specify the desired key/name for the object in the S3 bucket
  source = "../test-scripts/POC01_BBC_NavigateToHomepage_v02.jmx" # Path to the test script file
}

# Create EC2 instances

# Specify the name and size of the EC2 instance for the JMeter controller
resource "aws_instance" "jmeter_controller" {
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
    Name = "JMeter Controller" # Add a name to the respective EC2 instance
  }

  # Specify what will happen on the EC2 instance once it has been created
  user_data = local.init_jmeter_controller
}

# Create Elastic IP for the EC2 instance
resource "aws_eip" "jmeter_controller-EIP" {
  provider = aws
  instance = aws_instance.jmeter_controller.id
  tags = {
    Name = "jmeter_controller-EIP"
  }
}

# Associate Elastic IP to Linux server
resource "aws_eip_association" "jmeter_controller-EIP-Association" {
  instance_id   = aws_instance.jmeter_controller.id
  allocation_id = aws_eip.jmeter_controller-EIP.id
}

# Specify the name and size of the EC2 instance for the JMeter worker
resource "aws_instance" "jmeter_worker" {
  count                       = var.jmeter_worker_count # Specify the number of JMeter worker EC2 instances to create
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
    Name = "JMeter-Worker-${count.index + 1}" # Add a unique name to the respective EC2 instance
  }

  # Specify what will happen on the EC2 instance once it has been created
  user_data = local.init_jmeter_worker
}

# Create Elastic IP for the EC2 instance
resource "aws_eip" "jmeter_worker-EIP" {
  count = var.jmeter_worker_count
  #provider = aws
  tags = {
    Name = "jmeter_worker-EIP-${count.index + 1}"
  }
}

# Associate Elastic IP to Linux server
resource "aws_eip_association" "jmeter_worker-EIP-Association" {
  count         = var.jmeter_worker_count
  instance_id   = element(aws_instance.jmeter_worker.*.id, count.index)
  allocation_id = element(aws_eip.jmeter_worker-EIP.*.id, count.index)
}
