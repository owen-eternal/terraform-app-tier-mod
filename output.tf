output "security_group_id" {
  value = module.tf-aws-network.web_security_group_id
}

output "subnets" {
  value = module.tf-aws-network.web_subnet_ids
}


output "tagName" {
  value = module.tf-aws-network.tag_name
}

output "launch_template_id" {
  value = aws_launch_template.launch-blueprint.id
}
