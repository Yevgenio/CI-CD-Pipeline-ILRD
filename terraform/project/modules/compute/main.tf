# Register SSH key with AWS
resource "aws_key_pair" "my_key" {
  key_name   = "terraform-key"
  public_key = file("~/.ssh/terraform-key.pub")
}

# IAM Role for SSM
resource "aws_iam_role" "ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Attach SSM policy to role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Allow EKS describe for kubeconfig generation
resource "aws_iam_role_policy_attachment" "eks_describe" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Instance profile
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

# Single AZ instances - all in first private subnet
resource "aws_instance" "single_az" {
  for_each = var.single_az_instances

  ami                    = each.value.ami
  instance_type          = each.value.instance_type
  subnet_id              = var.private_subnet_ids[0]
  key_name               = aws_key_pair.my_key.key_name
  vpc_security_group_ids = [aws_security_group.my_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  user_data                   = each.value.user_data_file != "" ? file("${path.module}/scripts/${each.value.user_data_file}") : null
  user_data_replace_on_change = true

  tags = {
    Name  = each.key
    Owner = "Yevgeni"
  }
}
