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

resource "aws_kms_key" "example" {
    description = "Example Customer Master Key"
    enable_key_rotation = true # 1年に一度ローテーション
    is_enabled = true
    deletion_window_in_days = 30
}

resource "aws_kms_alias" "example" {
    name = "alias/example"
    target_key_id = aws_kms_key.example.key_id
}

resource "aws_ssm_parameter" "db_username" {
    name = "/db/username"
    value = "root"
    type = "String"
    description = "DBのユーザー名"
}

# ソースコード上にパスワードを載せるのはまずいのであとでAWS CLIから更新する
resource "aws_ssm_parameter" "db_raw_password" {
    name = "/db/password"
    value = "uninitialized"
    type = "SecureString"
    description = "DBのパスワード"

    lifecycle {
        ignore_changes = [value]
    }
}

resource "aws_db_parameter_group" "example" {
    name = "example"
    family = "mysql5.7"

    parameter {
        name = "character_set_database"
        value = "utf8mb4"
    }

    parameter {
        name = "character_set_server"
        value = "utf8mb4"
    }
}

resource "aws_db_option_group" "example" {
    name = "example"
    engine_name = "mysql"
    major_engine_version = "5.7"

    option {
        option_name = "MARIADB_AUDIT_PLUGIN"
    }
}

resource "aws_db_subnet_group" "example" {
    name = "example"
    subnet_ids = [aws_subnet.private_0.id, aws_subnet.private_1.id] # マルチAZ設定のため異なるAZの設定をする
}

resource "aws_db_instance" "example" {
    identifier = "example"
    engine = "mysql"
    engine_version = "5.7.25"
    instance_class = "db.t3.small"
    allocated_storage = 20
    max_allocated_storage = 100
    storage_type = "gp2" # 汎用SSD or プロビジョンドIOPSを指定 gp2は汎用SSD
    storage_encrypted = true
    kms_key_id = aws_kms_key.example.arn
    username = "admin"
    password = "VeryStrongPassword" # パスワードは必須項目で省略できないので、aws rds modify-db-instance コマンドで更新する
    multi_az = true
    publicly_accessible = false
    backup_window = "09:10-09:40" # UTC
    backup_retention_period = 30
    maintenance_window = "mon:10:10-mon:10:40" # RDSでは定期的にメンテナンスが行われる UTC
    auto_minor_version_upgrade = false
    deletion_protection = true # 削除保護
    skip_final_snapshot = false
    port = 3306
    apply_immediately = false
    vpc_security_group_ids = [module.mysql_sg.security_group_id]
    parameter_group_name = aws_db_parameter_group.example.name
    option_group_name = aws_db_option_group.example.arn
    db_subnet_group_name = aws_db_option_group.example.name

    lifecycle {
        ignore_changes = [password]
    }
}

module "mysql_sg" {
    source = "./security_group"
    name = "mysql-sg"
    vpc_id = aws_vpc.example.id
    port = 3306
    cidr_blocks = [aws_vpc.example.cidr_block]
}

resource "aws_elasticache_parameter_group" "example" {
    name = "example"
    family = "redis5.0"

    parameter {
        name = "cluster-enabled"
        value = "no"
    }
}

resource "aws_elasticache_subnet_group" "example" {
    name = "example"
    subnet_ids = [aws_subnet.private_0.id, aws_subnet.private_1.id]
}

resource "aws_elasticache_replication_group" "example" {
    replication_group_id = "example"
    replication_group_description = "Cluster Disabled"
    engine = "redis" # memcached or redis
    engine_version = "5.0.4"
    number_cache_clusters = 3 # プライマリノードとレプリカノードを足した数
    node_type = "cache.m3.medium"
    snapshot_window = "09:10-10:10"
    snapshot_retention_limit = 7 # cacheとして保存するのでそんな長くなくていい
    maintenance_window = "mon:10:40-mon:11:40"
    automatic_failover_enabled = true # 自動フェイルオーバー
    port = 6379
    apply_immediately = false
    security_group_ids = [module.redis_sg.security_group_id]
    parameter_group_name = aws_elasticache_parameter_group.example.name
    subnet_group_name = aws_elasticache_subnet_group.example.name
}

module "redis_sg" {
    source = "./security_group"
    name = "redis-sg"
    vpc_id = aws_vpc.example.id
    port = 6379
    cidr_blocks = [aws_vpc.example.cidr_block]
}

resource "aws_ecs_repository" "example" {
    name = "example"
}

resource "aws_ecr_lifecyncle_policy" "example" {
    repository = aws_ecs_repository.example.name

    policy = <<EOF
    {
        "rules": [
            {
                "rulePriority": 1,
                "description": "Keep last 30 release tagged images",
                "selection": {
                    "tagStatus": "tagged",
                    "tagPrefixList": ["release"],
                    "countType": "imageCountMoreThan",
                    "countNumber": 30,
                },
                "action": {
                    "type": "expire"
                }
            }
        ]
    }
EOF
}

data "aws_iam_policy_document" "codebuild" {
    statement {
        effect = "Allow"
        resources = ["*"]

        actions = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownLoadUrlForLayer",
            "ecr:GetRepositoryPolicy",
            "ecr:DescribeRepositories",
            "ecr:ListImages",
            "ecr:DescribeImages",
            "ecr:BatchGetImage",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload",
            "ecr:PutImage",
        ]
    }
}

module "codebuild_role" {
    source = "./iam_role"
    name = "codebuild"
    identifier = "codebuild.amazonaws.com"
    policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_codebuild_project" "example" {
    name = "example"
    service_role = module.codebuild_role.iam_role_arn

    # ソースとアーティファクトの両方をCODEPIPELINEと指定することで、CodePipeLineと連携することを宣言
    source {
        type = "CODEPIPELINE"
    }

    artifacts {
        type = "CODEPIPELINE"
    }

    environment {
        type = "LINUX_CONTAINER"
        compute_type = "BUILD_GENERAL_SMALL"
        image = "aws/codebuild/standard:2.0" # codebuild image
        privileged_mode = true
    }
}

data "aws_iam_policy_document" "codepipeline" {
    statement {
        effect = "Allow"
        resources = ["*"]

        actions = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketVersioning",
            "codebuild:BatchGetBuilds",
            "codebuild:StartBuild",
            "ecs:DescribeServices",
            "ecs:DescribeTaskDefinition",
            "ecs:DescribeTasks",
            "ecs:ListTasks",
            "ecs:RegisterTaskDefinition",
            "ecs:UpdateService",
            "iam:PassRole",
        ]
    }
}

module "codepipeline_role" {
    source = "./iam_role"
    name = "codepipeline"
    identifier = "codepipeline.amazonaws.com"
    policy = data.aws_iam_policy_document.codepipeline.json
}

resource "aws_s3_bucket" "artifact" {
    bucket = "artifact-mimaki"

    lifecycle_rule {
        enabled = true

        expiration {
            days = "180"
        }
    }
}

resource "aws_codepipeline" "example" {
    name = "example"
    role_arn = module.codepipeline_role.iam_role_arn

    stage {
        name = "Source"

        action {
            name = "Source"
            category = "Source"
            owner = "ThirdParty"
            provider = "Github"
            version = 1
            output_artifacts = ["Source"]

            configuration = {
                Owner = "YOUR_GITHUB_NAME"
                Repo = "YOUR_GITHUB_REPOSITORY"
                Branch = "master"
                PollForSourceChanges = false # CodePipelineの起動はWebhookから行うため、ポーリングは無効にする
            }
        }
    }

    stage {
        name = "Build"
        category = "Build"
        owner = "AWS"
        provider = "CodeBuild"
        version = 1
        input_artifacts = ["Source"]
        output_artifacts = ["Build"]
        configuration = {
            ProjectName = aws_codebuild_project.example.id
        }
    }

    stage {
        name = "Deploy"

        action {
            name = "Deploy"
            category = "Deploy"
            owner = "AWS"
            provider = "ECS"
            version = 1
            input_artifacts = ["Build"]

            configuration = {
                ClusterName = aws_ecs_cluster.example.name
                ServiceName = aws_ecs_service.example.name
                FileName = "imagedefinition.json" # buildspec.ymlの最後に作成しているJSONファイル
            }
        }
    }

    artifact_store {
        location = aws_s3_bucket.artifact.id
        type = "S3"
    }
}

resource "aws_codepipeline_webhook" "example" {
    name = "example"
    target_pipeline = aws_codepipeline.example.name
    target_action = "Source"
    authentication = "GITHUB_HMAC"

    authentication_configuration {
        secret_token = "VeryRandomString"
    }

    filter {
        json_path = "$.ref"
        match_equals = "refs/heads/{Branch}"
    }
}

provider "github" {
    organization = "your-github-name"
}

resource "github_repository_webhook" "example" {
    repository = "your-repository"

    configuration {
        url = aws_codepipeline_webhook.example.url
        secret = "VeryRandomString" # aws_code_pupeline_webhook.exampleのsecretトークンと同じ値
        content_type = "json"
        insecure_ssl = false
    }

    events = ["push"]
}

data "aws_iam_policy_document" "ec2_for_ssm" {
    source_json = data.aws_iam_policy.ec2_for_ssm.policy

    statement {
        effect = "Allow"
        resources = ["*"]

        actions = [
            "s3:PutObject",
            "logs:PutLogEvents",
            "logs:CreateLogStream",
            "ecr:GetAuthorizationToken", # EC2でdocker pullできるように
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ssm:GetParameter", # SSMパラメータストアから設定情報を注入したコンテナを起動できるように
            "ssm:GetParameters",
            "ssm:GetParametersByPath",
            "kms:Decrypt",
        ]
    }
}

data "aws_iam_policy" "ec2_for_ssm" {
    arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

module "ec2_for_ssm_role" {
    source = "./iam_role"
    name = "ec2-for-ssm"
    identifier = "ec2.amazonaws.com"
    policy = data.aws_iam_policy_document.ec2_for_ssm.json
}

resource "aws_iam_instance_profile" "ec2_for_ssm" {
    name = "ec2-for-ssm"
    role = module.ec2_for_ssm_role.iam_role_name
}

resource "aws_instance" "example_for_operation" {
    ami = "ami-0c3fd0f5d33135a65"
    instance_type = "t3.micro"
    iam_instance_profile = aws_iam_instance_profile.ec2_for_ssm.name
    subnet_id = aws_subnet.private_0.id # privateにする
    user_data = file("./user_data.sh") # EC2作成時のプロビジョニングスクリプト
}

output "operation_instance_id" {
    value = aws_instance.example_for_operation.id
}

# オペレーションログ
resource "aws_s3_bucket" "operation" {
    bucket = "operation-pragmatic-terraform"

    lifecycle_rule {
        enabled = true

        expiration {
            days = "180"
        }
    }
}

resource "aws_cloudwatch_log_group" "operation" {
    name = "/operation"
    retention_in_days = "180"
}

resource "aws_ssm_document" "session_manager_run_shell" {
    name = "SSM-SessionManagerRunShell"
    document_type = "Session"
    document_format = "JSON"

    content = <<EOF
    {
        "schemaVersion": "1.0",
        "description": "Document to hold regional settings for Session Manager",
        "sessionType": "Standard_Stream",
        "input": {
            "s3BucketName": "${aws_s3_bucket.operation.id}",
            "cloudWatchLogGroupName": "${aws_cloudwatch_log_group.operation.name}"
        }
    }
    EOF
}


# CloudWatch Logsを入れるバケット
resource "aws_s3_bucket" "cloudwatch_logs" {
    bucket = "cloudwatch-logs-fargate-mimaki"

    lifecycle_rule {
        enabled = true

        expiration {
            days = "180"
        }
    }
}

# FirehoseのIAMポリシー
data "aws_iam_policy_document" "kinesis_data_firehose" {
    statement {
        effect = "Allow"

        actions = [
            "s3:AbortMultipartUpload",
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads",
            "s3:PutObject",
        ]

        resources = [
            "arn:aws:s3:::${aws_s3_bucket.cloudwatch_logs.id}",
            "arn:aws:s3:::${aws_s3_bucket.cloudwatch_logs.id}/",
        ]
    }
}

module "kinesis_data_firehose_role" {
    source = "./iam_role"
    name = "kinesis-data-firehose"
    identifier = "firehose.amazonaws.com"
    policy = data.aws_iam_policy_document.kinesis_data_firehose.json
}

# 配信ストリーム
resource "aws_kinesis_firehose_delivery_stream" "example" {
    name = "example"
    destination = "s3"

    s3_configuration {
        role_arn = module.kinesis_data_firehose_role.iam_role_arn
        bucket_arn = aws_s3_bucket.cloudwatch_logs.arn
        prefix = "ecs-scheduled-tasks/example/"
    }
}

# cloudwatch logsにkinesis data firehose の捜査権限とpassrole権限を付与
data "aws_iam_policy_document" "cloudwatch_logs" {
    statement {
        effect = "Allow"
        actions = ["firehose:*"]
        resources = ["arn:aws:firehose:ap-northeast-1:*:*"]
    }

    statement {
        effect = "Allow"
        actions = ["iam:PassRole"]
        resources = ["arn:aws:iam::*:role/cloudatch-logs"]
    }
}

module "cloudwatch_log_role" {
    source = "./iam_role"
    name = "cloudwatch-logs"
    identifier = "logs.ap-northeast-1.amazonaws.com"
    policy = data.aws_iam_policy_document.cloudwatch_logs.json
}

resource "aws_cloudwatch_log_subscription_filter" "example" {
    name = "example"
    log_group_name = aws_cloudwatch_log_group.for_ecs_scheduled_tasks.name
    destination_arn = aws_kinesis_firehose_delivery_stream.example.arn
    filter_pattern = "[]"
    role_arn = module.cloudwatch_logs_role.iam_role_arn
}
