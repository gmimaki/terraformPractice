variable "name" {
    description = "インスタンス名"
    type = string
    default = "HelloWorld"
}

variable "instance_type" {
    description = "インスタンスタイプ"
    type = string
    default = "t2.micro"
}