# Multi-Environment AWS Infrastructure with Terraform

A hands-on Terraform project that provisions reusable AWS infrastructure across development, staging, and production environments.

## Architecture

The project provisions:

- Custom AWS VPC
- Public subnet
- Internet Gateway
- Public route table
- Route table association
- Security group allowing HTTP traffic
- EC2 instance
- Dynamic Ubuntu AMI lookup
- S3 remote Terraform state
- State locking
- Separate state for dev, staging, and production

Traffic flow:

Internet → Internet Gateway → Public Route Table → Public Subnet → EC2

The EC2 instance is protected by a security group controlling inbound and outbound traffic.

## Project Structure

```text
terraform-aws-multi-environment/
├── bootstrap/
├── modules/
│   └── networking/
└── environments/
    ├── dev/
    ├── stag/
    └── prod/
```

The networking module contains reusable VPC, subnet, routing, Internet Gateway, and security group configuration.

Each environment reuses the same module while supplying its own configuration values.

## Environment Isolation

Development, staging, and production are separated into individual directories.

Environment-specific values are supplied through `.tfvars` files.

Example values include:

```hcl
environment   = "dev"
instance_type = "t3.micro"
region        = "eu-west-2"
```

This allows the same Terraform configuration to be reused across multiple environments.

## Remote State

Terraform state is stored remotely in Amazon S3 instead of being stored only on a local machine.

Separate state keys isolate each environment:

```text
dev/terraform.tfstate
stag/terraform.tfstate
prod/terraform.tfstate
```

State locking is enabled to reduce the risk of concurrent Terraform operations modifying the same state.

The S3 backend bucket is provisioned separately through the bootstrap configuration.

## Reusable Networking Module

The networking module creates the common networking infrastructure and exposes outputs such as:

```text
vpc_id
subnet_id
security_group_id
```

The environment configuration consumes these outputs when provisioning the EC2 instance.

This creates implicit Terraform dependencies between the EC2 resource and networking infrastructure.

## Dynamic AMI Lookup

Instead of hardcoding an AMI ID, an AWS AMI data source dynamically retrieves a suitable Ubuntu image.

Example:

```hcl
ami = data.aws_ami.ubuntu.id
```

This makes the configuration more reusable and avoids depending on a fixed AMI ID.

## Terraform Workflow

Initialise:

```bash
terraform init
```

Format:

```bash
terraform fmt
```

Validate:

```bash
terraform validate
```

Generate an environment-specific plan:

```bash
terraform plan -var-file="dev.tfvars"
```

For production, a saved plan can be reviewed before applying:

```bash
terraform plan -var-file="prod.tfvars" -out="prod.tfplan"
terraform apply "prod.tfplan"
```

## Terraform Concepts Demonstrated

This project demonstrates practical use of Terraform providers, resources, variables, outputs, modules, data sources, implicit dependencies, remote state, state locking, environment isolation, reusable infrastructure code, and Terraform planning and validation.

## Key Learning Outcomes

Building this project strengthened my understanding of Infrastructure as Code, AWS networking, reusable Terraform modules, multi-environment infrastructure, remote state management, dependency handling, and safer infrastructure deployment workflows.
