# get the public IP of the master node
output "master_public_ip" {
    value = module.ec2_instance["master"].public_ip
}
output "worker1_public_ip" {
    value = module.ec2_instance["worker1"].public_ip
}
output "worker2_public_ip" {
    value = module.ec2_instance["worker2"].public_ip
}