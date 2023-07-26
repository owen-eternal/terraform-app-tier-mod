output "security_group_id" {
  value = module.tf-aws-network.web_security_group_id
}

output "subnets" {
  value = module.tf-aws-network.web_subnet_ids
}


output "tagName" {
  value = module.tf-aws-network.tag_name
}
