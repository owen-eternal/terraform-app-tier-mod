#################################################
################ local ##########################
#################################################

locals {
  http_port = var.web_port
}

################################################
############### Resources ######################
################################################

# Amazon ECS Optimised image
data "aws_ami" "amazon_linux_2" {
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }

  owners = ["amazon"]
}

################################################
############### Resources ######################
################################################

resource "aws_launch_template" "capacity-temp" {
  image_id               = var.app_ami
  instance_type          = var.app_instance_type
  key_name               = var.ssh_key_pair
  user_data              = base64encode(data.template_file.user_data.rendered)
  name_prefix            = "${var.prefix}-asg"
  vpc_security_group_ids = [var.web_security_group]

  iam_instance_profile {
    arn = var.iam_instance_profile_arn
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web-asg" {
  name                  = "${var.prefix}-WEB_ASG"
  min_size            = 0
  max_size            = 2
  desired_capacity    = 0
  health_check_type     = "ALB"
  protect_from_scale_in = true
  vpc_zone_identifier = var.web_subnets

  launch_template {
    id      = aws_launch_template.capacity-temp.id
    version = "$Default"
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

# Capacity Provider.
resource "aws_ecs_capacity_provider" "web-capacity-provider" {
  name = "${var.prefix}-ECSWEB-CaProvider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.web-asg.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "cas" {
  cluster_name       = aws_ecs_cluster.web-cluster.name
  capacity_providers = [aws_ecs_capacity_provider.web-capacity-provider.name]
}

resource "aws_lb" "web-lb" {
  name               = "${var.prefix}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.lb_security_group]
  subnets            = var.web_subnets
}

resource "aws_lb_listener" "web-http-listener" {
  load_balancer_arn = aws_lb.web-lb.arn
  port              = local.http_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web-tg.arn
  }
}

resource "aws_lb_target_group" "web-tg" {
  name     = "${var.prefix}-tg"
  port     = local.http_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_autoscaling_attachment" "web-atg-tg-att" {
  autoscaling_group_name = aws_autoscaling_group.web-asg.id
  lb_target_group_arn    = aws_lb_target_group.web-tg.arn
}


# ECS cluster.
resource "aws_ecs_cluster" "web-cluster" {

  name = "${var.prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  lifecycle {
    create_before_destroy = true
  }
}