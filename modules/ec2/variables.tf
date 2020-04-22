variable "name" {
    description = "インスタンス名"
    type = string
}

variable "instance_type" {
    description = "インスタンスタイプ"
    type = string
    default = "t2.micro"
}