# Terraform module for creating 3 EC2s in aws
## It reads values vars from main.env file:
```
$vpc_id
$vpc_sg_id
$key_pair
$ubuntu_ami
```
## Then It creates them by for-looping these strings (master, worker1, & worker2)

## The EC2s are created with 
```
instance type "t2.medium" 
region "frankfurt" 
volume type "gp2"
volume size "20GB"
```

## Then it ouputs the public ip of each ec2 for later use in ansible

### make sure to check if the security group allows ssh from your ip address
### make sure to check if the key pair is in the same directory as the terraform files
### if there's a key in the region that is not yours and the script want you to copy it create another one with cli from the hostname script and copy it in terraform directory
### when you destroy the infra using 'terraform destroy' it will pop up a msg of empy vars, just press enter to continue 
    