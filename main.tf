#################################################
################ local #########################
#################################################

locals {
  http_port = var.web_port
}

################################################
############### Resources ######################
################################################

resource "aws_launch_template" "launch-blueprint" {
  image_id               = var.app_ami
  instance_type          = var.app_instance_type
  key_name               = var.ssh_key_pair
  name_prefix            = "${var.prefix}-asg"
  vpc_security_group_ids = [var.web_security_group]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web-asg" {
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = var.web_subnets

  launch_template {
    id      = aws_launch_template.launch-blueprint.id
    version = "$Default"
  }

  lifecycle {
    ignore_changes = [max_size, target_group_arns]
  }
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