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

module "sample_ec2" {
    source = "../modules/ec2"
    name = "HelloWorld"
}