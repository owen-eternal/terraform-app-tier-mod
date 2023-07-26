####### VPC Module Variables ########
variable "vpc_cdir" {}
variable "project_name" {}
variable "web_server_port" {}
variable "db_server_port" {}
variable "subnet_cdir" {}

####### APP-Tier Module Variables ########
variable "app_ami" {}
variable "app_instance_type" {}
variable "user_data" {}
variable "ssh_key_pair" {}
