provider "aws" {
    version = "2.23.0"
    region = "ap-northeast-1"
}

terraform {
    required_version = "0.12.6"
    backend "s3" {
        bucket = "tfstate-mimaki" #S3バケット名 tfstateを置く場所
        key = "sample_ec2/terraform.tfstate"
        region = "ap-northeast-1"
    }
}

module "web_server" {
    source = "./modules/ec2/"
    name = "HelloWorld"
    instance_type = "t3.micro"
}

output "public_dns" {
    value = module.web_server.public_dns
}
