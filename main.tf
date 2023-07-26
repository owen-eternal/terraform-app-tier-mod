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