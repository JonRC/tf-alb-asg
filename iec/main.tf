
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_default_vpc" "default" {

}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [aws_default_vpc.default.id]
  }
}

resource "aws_security_group" "server_security_group" {
  name = "server-security-group"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "local_file" "user_data" {
  filename = "../server-user-data.sh"
}

resource "aws_launch_template" "server_template" {
  name                 = "server-template"
  image_id             = "ami-0e731c8a588258d0d"
  instance_type        = "t3.nano"
  user_data            = base64encode(data.local_file.user_data.content)
  security_group_names = [aws_security_group.server_security_group.name]
}

resource "aws_autoscaling_group" "autoscaling" {
  name               = "server-autoscaling-group"
  availability_zones = ["us-east-1a"]
  max_size           = 3
  min_size           = 1

  launch_template {
    id      = aws_launch_template.server_template.id
    version = aws_launch_template.server_template.latest_version
  }
}

resource "aws_security_group" "alb_security_group" {
  name = "alb-security-group"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "alb" {
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb_security_group.id]
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.alb.arn
  protocol          = "HTTP"
  port              = 80
  default_action {
    target_group_arn = aws_alb_target_group.target_group.arn
    type             = "forward"
  }
}

resource "aws_alb_target_group" "target_group" {
  name     = "server-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_default_vpc.default.id
  health_check {
    matcher = "200,304"
  }
}

resource "aws_autoscaling_attachment" "target_group" {
  autoscaling_group_name = aws_autoscaling_group.autoscaling.name
  lb_target_group_arn    = aws_alb_target_group.target_group.arn
}
