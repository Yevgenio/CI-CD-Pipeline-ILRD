# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0 # all ports
    to_port     = 0
    protocol    = "-1" # all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-alb-sg"
      Environment = var.environment
    }
  )
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.environment}-alb"    # name of the ALB
  internal           = false                       # false for internet ; true for internal
  load_balancer_type = "application"               # layer 7
  security_groups    = [aws_security_group.alb.id] # attach the SG
  subnets            = var.public_subnet_ids       # public subnets

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-alb"
      Environment = var.environment
    }
  )
}

# Target Group - GitLab (port 80)
resource "aws_lb_target_group" "gitlab" {
  name     = "${var.environment}-gitlab-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = var.health_check_path # default var is "/"
    protocol            = "HTTP"
    matcher             = "200-399" # http status codes considered healthy
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-gitlab-tg"
      Environment = var.environment
    }
  )
}

# Target Group - Jenkins Controller (port 8080)
resource "aws_lb_target_group" "jenkins" {
  name     = "${var.environment}-jenkins-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/login" # Jenkins login page
    protocol            = "HTTP"
    matcher             = "200-399"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-jenkins-tg"
      Environment = var.environment
    }
  )
}

# Target Group - Jenkins Agent (port 80)
resource "aws_lb_target_group" "agent" {
  name     = "${var.environment}-agent-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = var.health_check_path # default var is "/"
    protocol            = "HTTP"
    matcher             = "200-399"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-agent-tg"
      Environment = var.environment
    }
  )
}

# Target Group Attachment - GitLab
resource "aws_lb_target_group_attachment" "gitlab" {
  target_group_arn = aws_lb_target_group.gitlab.arn
  target_id        = var.gitlab_instance_id
  port             = 80
}

# Target Group Attachment - Jenkins Controller
resource "aws_lb_target_group_attachment" "jenkins" {
  target_group_arn = aws_lb_target_group.jenkins.arn
  target_id        = var.jenkins_instance_id
  port             = 8080
}

# Target Group Attachment - Jenkins Agent
resource "aws_lb_target_group_attachment" "agent" {
  target_group_arn = aws_lb_target_group.agent.arn
  target_id        = var.agent_instance_id
  port             = 80
}

# Target Group - EKS WeatherApp (NodePort)
resource "aws_lb_target_group" "eks_app" {
  name     = "${var.environment}-eks-app-tg"
  port     = var.eks_app_node_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = var.health_check_path
    port                = var.eks_app_node_port
    protocol            = "HTTP"
    matcher             = "200-399"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.environment}-eks-app-tg"
      Environment = var.environment
    }
  )
}

# Attach EKS node group ASG to the target group (nodes auto-register/deregister)
resource "aws_autoscaling_attachment" "eks_app" {
  autoscaling_group_name = var.eks_node_group_asg_name
  lb_target_group_arn    = aws_lb_target_group.eks_app.arn
}

# HTTP Listener - Redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn # attach to ALB
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect" # dont serve traffic, redirect it

    redirect {
      port        = "443"      # redirect to 443
      protocol    = "HTTPS"    # using HTTPS
      status_code = "HTTP_301" # 301 = permanent redirect
    }
  }
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06" # modern TLS policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"                       # forward traffic
    target_group_arn = aws_lb_target_group.eks_app.arn # to the EKS weatherapp
  }
}

# Listener Rule - gitlab.domain.com
resource "aws_lb_listener_rule" "gitlab" {
  listener_arn = aws_lb_listener.https.arn # attach to HTTPS listener     
  priority     = 200

  action {
    type             = "forward"                      # forward traffic
    target_group_arn = aws_lb_target_group.gitlab.arn # to the gitlab ARN
  }

  condition {
    host_header {
      values = ["gitlab.${var.domain_name}"]
    }
  }
}

# Listener Rule - jenkins.domain.com
resource "aws_lb_listener_rule" "jenkins" {
  listener_arn = aws_lb_listener.https.arn # attach to HTTPS listener       
  priority     = 300

  action {
    type             = "forward"                       # forward traffic
    target_group_arn = aws_lb_target_group.jenkins.arn # to the jenkins ARN
  }

  condition {
    host_header {
      values = ["jenkins.${var.domain_name}"]
    }
  }
}

# Listener Rule - agent.domain.com
resource "aws_lb_listener_rule" "agent" {
  listener_arn = aws_lb_listener.https.arn # attach to HTTPS listener
  priority     = 400

  action {
    type             = "forward"                     # forward traffic
    target_group_arn = aws_lb_target_group.agent.arn # to the agent ARN
  }

  condition {
    host_header {
      values = ["agent.${var.domain_name}"]
    }
  }
}

# Listener Rule - app/eks.domain.com (EKS WeatherApp via NodePort)
resource "aws_lb_listener_rule" "eks_app" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 50

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_app.arn
  }

  condition {
    host_header {
      values = ["app.${var.domain_name}", "eks.${var.domain_name}"]
    }
  }
}
