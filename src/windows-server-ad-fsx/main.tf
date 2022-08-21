locals {
  region = "eu-west-1"
}

# Create a best practice VPC using the Terraform VPC module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.environment}-windows-ad-fsx-aws"
  cidr = "10.0.0.0/16"

  azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_ipv6 = true

  enable_nat_gateway = false
  single_nat_gateway = true

  tags = {
    Environment = "${var.environment}"
  }
}

# Create an active directory
resource "aws_directory_service_directory" "managed-ad" {
  name     = "corp.business.local"
  edition  = "Standard"
  type     = "MicrosoftAD"
  password = "AklTYa98029"
  size     = "Small"

  vpc_settings {
    vpc_id     = module.vpc.vpc_id
    subnet_ids = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]
  }

  tags = {
    Project = "foo"
  }
}

# Associate the domain IP's of the AWS Managed AD with the VPC
resource "aws_vpc_dhcp_options" "dns_resolver" {
  domain_name_servers = [sort(aws_directory_service_directory.managed-ad.dns_ip_addresses)[0], sort(aws_directory_service_directory.managed-ad.dns_ip_addresses)[1]]
  domain_name         = "corp.business.local"
}

resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = module.vpc.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.dns_resolver.id
}

# Add a file share
resource "aws_fsx_windows_file_system" "main-file-share" {
  active_directory_id = aws_directory_service_directory.managed-ad.id
  storage_capacity    = 32
  subnet_ids          = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]
  preferred_subnet_id = module.vpc.private_subnets[0]
  throughput_capacity = 32
  deployment_type     = "MULTI_AZ_1"
}

module "ec2_web_1" {
  source = "./modules/domain-joined-ec2"
  environment = var.environment
  name = "${var.environment}-windows-ad-fsx-aws-web-1"
  subnet_id = module.vpc.public_subnets[0]
  directory_id = aws_directory_service_directory.managed-ad.id
  directory_name = aws_directory_service_directory.managed-ad.name
  directory_domain_ip = aws_directory_service_directory.managed-ad.dns_ip_addresses
}

module "ec2_web_2" {
  source = "./modules/domain-joined-ec2"
  environment = var.environment
  name = "${var.environment}-windows-ad-fsx-aws-web-2"
  subnet_id = module.vpc.public_subnets[1]
  directory_id = aws_directory_service_directory.managed-ad.id
  directory_name = aws_directory_service_directory.managed-ad.name
  directory_domain_ip = aws_directory_service_directory.managed-ad.dns_ip_addresses
}