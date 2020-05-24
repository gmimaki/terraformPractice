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

# ドメインはあらかじめroute53で手動で登録しておく
data "aws_route53_zone" "example" {
    name = "mimaki.com"
}

resource "aws_route53_zone" "test_example" {
    name = "test.mimaki.com"
}

# ALBとの紐付け
resource "aws_route53_record" "example" {
    zone_id = data.aws_route53_zone.example.zone_id
    name = data.aws_route53_zone.example.name
    type = "A" # AWS独自のALIASレコードもtype Aで指定する albだけでなくS3, CloudFrontの紐付けも可能

    alias {
        name = aws_lb.example.dns_name
        zone_id = aws_lb.example.zone_id
        evaluate_target_health = true
    }
}

output "domain_name" {
    value = aws_route53_record.example.name
}

# 証明書
resource "aws_acm_certificate" "example" {
    domain_name = aws_route53_record.example.name
    subjective_alternative_names = [] # ドメイン名追加
    validation_method = "DNS" # ドメインの所有権の検証方法 DNS検証orEメール検証 自動更新したい場合はDNS検証を選択

    lifecycle {
        create_before_destroy = true # リソースを作成してからリソースを削除する形の置き換え
    }
}

# 検証用DNSレコード
resource "aws_route53_record" "example_certificate" {
    name = aws_acm_certificate.example.domain_validation_options[0].resource_record_name
    type = aws_acm_certificate.example.domain_validation_options[0].resource_record_type
    records = [aws_acm_certificate.example.domain_validation_options[0].resource_record_value]
    zone_id = data.aws_route53_zone.example.id
    ttl = 60
}

# 検証の待機 SSL証明書の検証が完了するまで待つ
resource "aws_acm_certificate_validation" "example" {
    certificate_arn = aws_acm_certificate.example.arn
    validation_record_fqdns = [aws_route53_record.example_certificate.fqdn]
}

# ALBのHTTPSリスナー
resource "aws_lb_listener" "https" {
    load_balancer_arn = aws_lb.example.arn
    port = "443"
    protocol = "HTTPS"
    certificate_arn = aws_acm_certificate.example.arn
    ssl_policy - "ELBSecurityPolicy-2016-08" # AWSで推奨されているSecurtyPolicy

    default_action {
        type = "fixed_response"

        fixed_response {
            content_type = "text/plain"
            message_body = "これは「HTTPS」です"
            status_code = "200"
        }
    }
}

resource "aws_lb_listener" "redirect_http_to_https" {
    load_balancer_arn = aws_lb.example.arn
    port = "8080"
    protocol = "HTTP"

    default_action {
        type = "redirect"

        redirect {
            port = "443"
            protocol = "HTTPS"
            status_code = "HTTP_301"
        }
    }
}

# ターゲットグループとECSの紐付け
resource "aws_lb_target_group" "example" {
    name = "example"
    target_type = "ip" # EC2の場合はEC2指定 Fargateの場合はIPアドレス指定 Lambda関数指定も可能
    vpc_id = aws_vpc.example.id # ターゲットタイプでIPアドレスを指定した場合はvpc_id, port, protocolを設定する必要
    port = 80
    protocol = "HTTP" # HTTPSの終端はALBで行うため、protocolにはHTTPを指定することが多い
    deregistration_delay = 300 # ターゲットの登録を解除する前にALBが待機する時間

    health_check {
        path = "/"
        healthy_threshold = 5
        unhealthy_threshold = 2
        timeout = 5
        internal = 30
        matcher = 200
        port = "traffic-port"
        protocol = "HTTP"
    }

    depends_on = [aws_lb.example] # 依存関係制御
}

# リスナールール
resource "aws_lb_listener_rule" "example" {
    listener_arn = aws_lb_listener.https.arn
    priority = 100 # 数字が小さいほど優先順位が高い

    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.example.arn
    }

    condition {
        field = "path-pattern"
        values = ["/*"]
    }
}

resource "aws_ecs_cluster" "example" {
    name = "example"
}

resource "aws_ecs_task_definition" "example" {
    family = "example"
    cpu = "256"
    memory = "512"
    network_mode = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    container_definitions = file("./container_definitions.json")
    execution_role_arn = module.ecs_task_execution_role.iam_role_arn
}

resource "aws_ecs_service" "example" {
    name = "example"
    cluster = aws_ecs_cluster.example.arn
    task_definition = aws_ecs_task_definition.example.arn
    desired_count = 2
    launch_type = "FARGATE"
    platform_version = "1.3.0"
    health_check_grace_period_seconds = 60

    network_configuration {
        assign_public_ip = false
        security_groups = [module.nginx_sg.security_group_id]

        subnets = [
            aws_subnet.private_0.id,
            aws_subnet.private_1.id,
        ]
    }

    load_balancer {
        target_group_arn = aws_lb_target_group.example.arn
        container_name = "example"
        container_port = 80
    }

    lifecycle {
        ignore_changes = [task_definition]
    }
}

module "nginx_sg" {
    source = "./security_group"
    name = "nginx-sg"
    vpc_id = aws_vpc.example.id
    port = 80
    cidr_blocks = [aws_vpc.example.cidr_block]
}

resource "aws_cloudwatch_log_group" "for_ecs" {
    name = "/ecs/example"
    retention_in_days = 180
}

data "aws_iam_policy" "ecs_task_execution_role_policy" {
    arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" # cloudwatch logsやECRに対する権限
}

data "aws_iam_policy_document" "ecs_task_execution" {
    source_json = data.aws_iam_policy.ecs_task_execution_role_policy.policy

    statement {
        effect = "Allow"
        actions = ["ssm:GetParameters", "kms:Decrypt"]
        resources = ["*"]
    }
}

module "ecs_task_execution_role" {
    source = "./iam_role"
    name = "ecs-task-execution"
    identifier = "ecs-tasks.amazonaws.com"
    policy = data.aws_iam_policy_document.ecs_task_execution.json
}

resource "aws_cloudwatch_log_group" "for_ecs_scheduled_tasks" {
    name = "/ecs-scheduled-tasks/example"
    retention_in_days = 180
}

resource "aws_ecs_task_definition" "example_batch" {
    family = "example-batch"
    cpu = "256"
    memory = "512"
    network_mode = "awsvpu"
    requires_compatibilities = ["FARGATE"]
    container_definitions = file("./batch_container_definitions.json")
    execution_role_arn = module.ecs_task_execution_role.iam_role_arn
}

module "ecs_events_role" {
    source = "./iam_role"
    name = "ecs-events"
    identifier = "events.amazonaws.com"
    policy = data.aws_iam_policy.ecs_events_role_policy.policy
}

data "aws_iam_policy" "ecs_events_role_policy" {
    arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}

resource "aws_cloudwatch_event_rule" "example_batch" {
    name = "example-batch"
    description = "バッチ処理です"
    scheduled_expression = "cron(*/2 * * * ? *)" # 東京RegionでもUTC
}

resource "aws_cloudwatch_event_target" "example_batch" {
    target_id = "example-batch"
    rule = aws_cloudwatch_event_rule.example_batch.name
    role_arn = module.ecs_events_role.iam_role_arn
    arn = aws_ecs_cluster.example.arn

    ecs_target {
        launch_type = "FARGATE"
        task_count = 1
        platform_version = "1.3.0"
        task_definition_arn = aws_ecs_task_definition.example_batch.arn

        network_configuration {
            assign_public_ip = "false"
            subnets = [aws_subnet.private_0.id]
        }
    }
}
