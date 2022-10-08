provider "aws" {
  # region = "eu-central-1"
  region = "eu-west-2"
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  for_each = toset(["master", "worker1", "worker2"])

#   name = ${each.key}
  name = "k8s-${each.key}"

  ami                    = "ami-04842bc62789b682e"
  instance_type          = "t2.medium"
  key_name               = "k8s"
  monitoring             = true
  vpc_security_group_ids = ["sg-0e2dbd9064902a423"]
  
  # change storage size to 20GB
  root_block_device = [
    {
      volume_size = 20
    }
  ]

  # create snapshot on start
  ebs_block_device = [
    {
      device_name           = "/dev/xvda"
      volume_type           = "gp2"
      volume_size           = 20
      delete_on_termination = true
      snapshot_on_create    = true
    }
  ]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

/* ------------------------------ london region ----------------------------- */
  # region = "eu-west-2"
  # ami                    = "ami-04842bc62789b682e"
  # instance_type          = "t2.medium"
  # key_name               = "k8s"
  # monitoring             = true
  # vpc_security_group_ids = ["sg-0e2dbd9064902a423"]
# vpc                    = "vpc-0eb1059fafa3d0b04"
/* -------------------------------------------------------------------------- */

/* ----------------------------------------------------------------------- ** ----------------------------------------------------------------------- */

/* ---------------------------- frankfurt region ---------------------------- */
  # region = "eu-central-1"
  # ami                    = "ami-0caef02b518350c8b"
  # instance_type          = "t2.medium"
  # key_name               = "new_k8"
  # monitoring             = true
  # vpc_security_group_ids = ["sg-09987c12c5e7bf5ec"]
# vpc                    = "vpc-0a096a58aac8ec7c7"
/* -------------------------------------------------------------------------- */