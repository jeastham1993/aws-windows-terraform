variable "environment" {
  description = "The environemnt name"
  type        = string
  default = "dev"
}

variable "name" {
  description = "The name of the EC2 instance"
  type        = string
}

variable "subnet_id" {
  description = "The subnet to launch the EC2 instance into"
  type        = string
}

variable "directory_id" {
  description = "The ID of the AWS Managed AD"
  type        = string
}

variable "directory_name" {
  description = "The name of the AWS Manged AD"
  type        = string
}

variable "directory_domain_ip" {
  description = "The IP addresses of the AD"
  type        = set(string)
}
