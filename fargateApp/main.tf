variable "AWS_ACCOUNT_ID" {}

module "describe_regions_for_ec2" {
    source = "./iam_role"
    name = "describe-regions-for-ec2"
    identifier = "ec2.amazonaws.com"
    policy = data.aws_iam_policy_document.allow_describe_regions.json
}

module "example_sg" {
    source = "./security_group"
    name = "module-sg"
    vpc_id = aws_vpc.example.id
    port = 80
    cidr_blocks = ["0.0.0.0/0"]
}

data "aws_iam_policy_document" "allow_describe_regions" {
    statement {
        effect = "Allow"
        actions = ["ec2:DescribeRegions"]
        resources = ["*"]
    }
}

resource "aws_iam_policy" "example" {
    name = "example"
    policy = data.aws_iam_policy_document.allow_describe_regions.json
}

data "aws_iam_policy_document" "ec2_assume_role" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}

resource "aws_iam_role" "example" {
    name = "example"
    assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "example" {
    role = aws_iam_role.example.name
    policy_arn = aws_iam_policy.example.arn
}

resource "aws_vpc" "example" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true # AWSのDNSサーバーによる名前解決を有効に
    enable_dns_hostnames = true # VPC内のリソースにパブリックDNSホスト名を自動的に割り当てるため

    tags = {
        Name = "example"
    }
}

resource "aws_subnet" "public_0" {
    vpc_id = aws_vpc.example.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = true # サブネット内で起動したインスタンスにパブリックIPアドレスを自動で割り当てる
    availability_zone = "ap-northeast-1a"
}

resource "aws_subnet" "public_1" {
    vpc_id = aws_vpc.example.id
    cidr_block = "10.0.2.0/24"
    map_public_ip_on_launch = true # サブネット内で起動したインスタンスにパブリックIPアドレスを自動で割り当てる
    availability_zone = "ap-northeast-1c"
}

resource "aws_internet_gateway" "example" {
    vpc_id = aws_vpc.example.id
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.example.id
}

resource "aws_route" "public" {
    route_table_id = aws_route_table.public.id
    gateway_id = aws_internet_gateway.example.id
    destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "public_0" { # サブネットとルートテーブルの関連付けを忘れるとデフォルトルートテーブルと紐づく(アンチパターン)
    subnet_id = aws_subnet.public_0.id
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1" { # サブネットとルートテーブルの関連付けを忘れるとデフォルトルートテーブルと紐づく(アンチパターン)
    subnet_id = aws_subnet.public_1.id
    route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private_0" {
    vpc_id = aws_vpc.example.id
    cidr_block = "10.0.65.0/24"
    availability_zone = "ap-northeast-1a"
    map_public_ip_on_launch = false
}

resource "aws_subnet" "private_1" {
    vpc_id = aws_vpc.example.id
    cidr_block = "10.0.66.0/24"
    availability_zone = "ap-northeast-1c"
    map_public_ip_on_launch = false
}

resource "aws_route_table" "private_0" {
    vpc_id = aws_vpc.example.id
}

resource "aws_route_table" "private_1" {
    vpc_id = aws_vpc.example.id
}

resource "aws_route_table_association" "private_0" {
    subnet_id = aws_subnet.private_0.id
    route_table_id = aws_route_table.private_0.id
}

resource "aws_route_table_association" "private_1" {
    subnet_id = aws_subnet.private_1.id
    route_table_id = aws_route_table.private_1.id
}

resource "aws_eip" "nat_gateway_0" { # NATゲートウェーにはEIPが必要
    vpc = true
    depends_on = [aws_internet_gateway.example] # EIPは暗黙的にインターネットゲートウェーに依存している
}

resource "aws_eip" "nat_gateway_1" { # NATゲートウェーにはEIPが必要
    vpc = true
    depends_on = [aws_internet_gateway.example] # EIPは暗黙的にインターネットゲートウェーに依存している
}

resource "aws_nat_gateway" "nat_gateway_0" {
    allocation_id = aws_eip.nat_gateway_0.id
    subnet_id = aws_subnet.public_0.id # プライベートではなくパブリックのサブネットを指定
    depends_on = [aws_internet_gateway.example] # NATゲートウェーは暗黙的にインターネットゲートウェーに依存している
}

resource "aws_nat_gateway" "nat_gateway_1" {
    allocation_id = aws_eip.nat_gateway_1.id
    subnet_id = aws_subnet.public_1.id # プライベートではなくパブリックのサブネットを指定
    depends_on = [aws_internet_gateway.example] # NATゲートウェーは暗黙的にインターネットゲートウェーに依存している
}

resource "aws_route" "private_0" {
    route_table_id = aws_route_table.private_0.id
    nat_gateway_id = aws_nat_gateway.nat_gateway_0.id
    destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private_1" {
    route_table_id = aws_route_table.private_1.id
    nat_gateway_id = aws_nat_gateway.nat_gateway_1.id
    destination_cidr_block = "0.0.0.0/0"
}

################# S3
resource "aws_s3_bucket" "private" {
    bucket = "mimaki-private-terraform"

    versioning {
        enabled = true
    }

    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm = "AES256"
            }
        }
    }
}

resource "aws_s3_bucket_public_access_block" "private" {
    bucket = aws_s3_bucket.private.id
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true
    restrict_public_buckets = true
}

resource "aws_s3_bucket" "public" {
    bucket = "mimaki-public-terraform"
    acl = "public-read"

    cors_rule {
        allowed_origins = ["*"]
        allowed_methods = ["GET"]
        allowed_headers = ["*"]
        max_age_seconds = 3000
    }
}

resource "aws_s3_bucket" "alb_log" {
    bucket = "alb-log-pragmatic-terraform-gmimaki"

    lifecycle_rule {
        enabled = true

        expiration {
            days = "180"
        }
    }
}

resource "aws_s3_bucket_policy" "alb_log" {
    bucket = aws_s3_bucket.alb_log.id
    policy = data.aws_iam_policy_document.alb_log.json
}

data "aws_iam_policy_document" "alb_log" {
    statement {
        effect = "Allow"
        actions = ["s3:PutObject"]
        resources = ["arn:aws:s3:::${aws_s3_bucket.alb_log.id}/*"]

        principals {
            type = "AWS"
            identifiers = [var.AWS_ACCOUNT_ID]
        }
    }
}


################### ALB
resource "aws_lb" "example" {
    name = "example"
    load_balancer_type = "application"
    internal = false
    idle_timeout = 60
    enable_deletion_protection = true # 削除保護

    subnets = [
        aws_subnet.public_0.id,
        aws_subnet.public_1.id,
    ]

    access_logs {
        bucket = aws_s3_bucket.alb_log.id
        enabled = true
    }

    security_groups = [
        module.http_sg.security_group_id,
        module.https_sg.security_group_id,
        module.http_redirect_sg.security_group_id,
    ]
}

output "alb_dns_name" {
    value = aws_lb.example.dns_name
}

module "http_sg" {
    source = "./security_group"
    name = "http-sg"
    vpc_id = aws_vpc.example.id
    port = 80
    cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
    source = "./security_group"
    name = "https-sg"
    vpc_id = aws_vpc.example.id
    port = 443
    cidr_blocks = ["0.0.0.0/0"]
}

module "http_redirect_sg" {
    source = "./security_group"
    name = "http-refirect-sg"
    vpc_id = aws_vpc.example.id
    port = 8080
    cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.example.arn
    port = "80"
    protocol = "HTTP"

    default_action {
        type = "fixed-response"

        fixed_response {
            content_type = "text/plain"
            message_body = "これは「HTTP」です"
            status_code = "200"
        }
    }
}
