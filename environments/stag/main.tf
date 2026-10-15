module "networking" {

  source      = "../../modules/networking"
  vpc_cidr    = "10.0.0.0/16"
  environment = var.environment
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"]
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = module.networking.subnet_id
  vpc_security_group_ids = [module.networking.security_group_id]

  tags = {
    Name = "${var.environment}-web"
  }
}