# Generate an AWS EC2 key pair in the directory where the Terraform code is run
# AWS EC2 stores the public key on your instance(s), and the private key is stored locally
# The private key allows the owner (or anyone who possesses it) to securely SSH into the associated EC2 instance(s)

# Generate a new RSA private key
resource "tls_private_key" "key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create an AWS key pair that is associated with the RSA private key
resource "aws_key_pair" "key_pair" {
  key_name   = "linux-key-pair"
  public_key = tls_private_key.key_pair.public_key_openssh
}

# Create a local file containing the RSA private key in the PEM format
resource "local_file" "ssh_key" {
  filename        = "${aws_key_pair.key_pair.key_name}.pem"
  content         = tls_private_key.key_pair.private_key_pem
  file_permission = "0600" # Ensure that the private key file is secure and accessible only by the owner
}
