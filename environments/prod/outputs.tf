output "vpc_id" {
  value = module.networking.vpc_id
}

output "subnet_id" {
  value = module.networking.subnet_id
}

output "security_group_id" {
  value = module.networking.security_group_id
}

output "ec2_public_ip" {
  value = aws_instance.web.public_ip
}