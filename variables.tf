variable "system_name" {
  type        = string
  default     = "azurelb"
  description = "(必須)サーバに適用したいすでに存在するリソースグループ名"
}

variable "location" {
  type        = string
  default     = "japaneast"
  description = "(必須)サーバに適用したいすでに存在するリソースグループ名"
}

variable "stage" {
  type        = string
  default     = "dev"
  description = "ステージ名"
}

variable "ssh_key_path" {
  type        = string
  description = "(必須)サーバにSSH接続するためのSSKキーのパス"
  default     = "~/.ssh/id_rsa.pub"
}

variable "virtual_machine_size" {
  type        = string
  default     = "Standard_B1ls"
  description = "サーバのサイズ"
}
