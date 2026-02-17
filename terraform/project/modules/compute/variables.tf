variable "vpc_id" {
  description = "VPC ID for the security group"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "single_az_instances" {
  description = "Instances to place in a single AZ (first private subnet). Set user_data_file to a script filename in the scripts/ directory."
  type = map(object({
    ami            = string
    instance_type  = string
    user_data_file = optional(string, "")
  }))
  default = {
    gitlab = {
      ami           = "ami-0026aef282f0bc395"
      instance_type = "t3.medium"
    }
    jenkins-controller = {
      ami           = "ami-07741070b4cf87861"
      instance_type = "t3.small"
    }
    jenkins-agent = {
      ami            = "ami-0b6c6ebed2801a5cb" #ami-0b6c6ebed2801a5cb = default ubuntu
      instance_type  = "t3.small"
      user_data_file = "jenkins-agent.sh"
    }
  }
}

variable "ingress_rules" {
  description = "List of ingress rules"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))

  default = [
    {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Jenkins"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Jenkins Agent"
      from_port   = 50000
      to_port     = 50000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "GitLab SSH"
      from_port   = 2424
      to_port     = 2424
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "egress_rules" {
  description = "List of egress rules"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))

  default = [
    {
      description = "Allow all outbound"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
