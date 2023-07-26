#################################################
################ Modules ########################
#################################################

module "tf-aws-network" {
  source          = "git@github.com:owen-eternal/tf-aws-network-mod.git"
  vpc_cdir        = var.vpc_cdir
  project_name    = var.project_name
  environment     = terraform.workspace
  web_server_port = var.web_server_port
  db_server_port  = var.db_server_port
  subnet_cdir     = var.subnet_cdir
}

################################################
############### Resources ######################
################################################

resource "aws_launch_template" "launch-blueprint" {
  image_id               = var.app_ami
  instance_type          = var.app_instance_type
  key_name               = var.ssh_key_pair
  name_prefix            = "${module.tf-aws-network.tag_name}-asg"
  user_data              = filebase64(var.user_data)
  vpc_security_group_ids = [module.tf-aws-network.web_security_group_id]

  lifecycle {
    create_before_destroy = true
  }
}