variable "ubuntu_ami" {
  description = "ubuntu-22.04 distro machine image in eu-central-1"
  default     = "ami-0faab6bdbac9486fb"
}
variable "ssh_key_name" {
  description = "aws private key name"
  default     = "KEY_NAME"
}
variable "region" {
  description = "the desired region"
  default = "eu-central-1"
}