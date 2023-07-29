####### VPC-Tier Module Variables ########
variable "vpc_cdir" {}
variable "project_name" {}
variable "environment" {}
variable "subnet_cdir" {}
variable "web_server_port" {}
variable "database" {}
variable "db_server_port" {}
variable "ipaddr" {}

####### APP-Tier Module Variables ########
variable "app_ami" {}
variable "app_instance_type" {}
variable "user_data" {}
variable "ssh_key_pair" {}
