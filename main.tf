#################################################
################ local ##########################
#################################################

locals {
  http_port = var.web_port
  container_name = "nginx-reverse-proxy"
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

# ECS container instance association.
data "template_file" "user_data" {
  template = file("user_data.sh")

  vars = {
    ecs_cluster_name = aws_ecs_cluster.web-cluster.name
  }
}

################################################
############### Resources ######################
################################################

# Launch template
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

# Autoscaling Group
resource "aws_autoscaling_group" "web-asg" {
  name                  = "${var.prefix}-WEB_ASG"
  min_size            = 0
  max_size            = 2
  desired_capacity    = 0
  health_check_type     = "ALB"
  protect_from_scale_in = true
  vpc_zone_identifier = var.web_subnets

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  launch_template {
    id      = aws_launch_template.capacity-temp.id
    version = "$Default"
  }

  instance_refresh {
    strategy = "Rolling"
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

# Loadbalancer
resource "aws_lb" "web-lb" {
  name               = "${var.prefix}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.lb_security_group]
  subnets            = var.web_subnets
}

# Listener
resource "aws_lb_listener" "web-http-listener" {
  load_balancer_arn = aws_lb.web-lb.arn
  port              = local.http_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web-tg.arn
  }
}

# Target group
resource "aws_lb_target_group" "web-tg" {
  name     = "${var.prefix}-tg"
  port     = local.http_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

# resource "aws_autoscaling_attachment" "web-atg-tg-att" {
#   autoscaling_group_name = aws_autoscaling_group.web-asg.id
#   lb_target_group_arn    = aws_lb_target_group.web-tg.arn
# }


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

# Task Definition.
resource "aws_ecs_task_definition" "web-task-definition" {
  family             = "${var.prefix}_ECSWEB_TD"
  execution_role_arn = var.task_exec_role
  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = var.container_image
      cpu       = 128
      memory    = 256
      essential = true
      portMappings = [
        {
          containerPort = local.http_port
          hostPort      = local.http_port
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# Cloudwatch log group
resource "aws_cloudwatch_log_group" "log_group" {
  name              = "/${var.prefix}/ecs/${local.container_name}"
  retention_in_days = 1
}

#ECS service
resource "aws_ecs_service" "web-service" {
  name                               = "${var.prefix}_ECSWEB_service"
  cluster                            = aws_ecs_cluster.web-cluster.id
  task_definition                    = aws_ecs_task_definition.web-task-definition.arn
  desired_count                      = 2

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  load_balancer {
    target_group_arn = aws_lb_target_group.web-tg.arn
    container_name   = local.container_name
    container_port   = local.http_port
  }

  capacity_provider_strategy {
    base    = 0
    weight  = 1
    capacity_provider = aws_ecs_capacity_provider.web-capacity-provider.name
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  lifecycle {
    ignore_changes = [desired_count] 
  }
}