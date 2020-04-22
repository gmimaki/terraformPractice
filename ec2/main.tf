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

# dataブロックで外部データを参照
data "aws_ami" "ubuntu" {
    most_recent = true

    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["099720109477"]
}

# resourceブロックでデプロイしたいリソース定義
resource "aws_instance" "web" {
    ami = data.aws_ami.ubuntu.id
    instance_type = var.instance_type
    tags = {
        Name = var.name
    }
}