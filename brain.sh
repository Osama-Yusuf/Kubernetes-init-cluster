#!/bin/bash

# This script creates 6 files in the current directory after the script is executed it deletes them.
# 1. hosts - contains the list of ip and hostname and to be copied to each node /etc/hosts with ansible playbook
# 2. hosts.txt - contains the list of ip and credentials for ansible to ssh to each node
# 3. ansible.cfg - contains rules for easier execution for ansible
# 4. k8s_init.sh - contains the list of commands to be executed on all nodes to initialze the cluster
# 5. playbook.yml - ansible playbook to to copy hosts file to each node and execute k8s_init.sh
# 6. token.sh - contains the command to get the token to join the cluster created by kubeadm init from master node

# import functions
source ./funcs/provision-ec2s.sh
source ./funcs/deployK8sLocally.sh
source ./funcs/deployK8sRemotely.sh
source ./funcs/destroy_et.sh

# all nodes must be the same user and have the same key
user_name="ubuntu"
key_name="my_key"

update_config_after_provision() {
  master_ip=$(echo $master_ip | tr -d '"')
  worker1_ip=$(echo $worker1_ip | tr -d '"')
  worker2_ip=$(echo $worker2_ip | tr -d '"')
  # update hosts file with the ips of the nodes
  sed -i "s/MASTER_IP/${master_ip}/g" nodes_config/etc_hosts.txt ansible/inventory.ini
  sed -i "s/WORKER_01_IP/${worker1_ip}/g" nodes_config/etc_hosts.txt ansible/inventory.ini
  sed -i "s/WORKER_02_IP/${worker2_ip}/g" nodes_config/etc_hosts.txt ansible/inventory.ini
}

if [ $# -eq 0 ]; then
  echo """No argument supplied. Use:
-t/--terraform for remote k8s deployment.
-l/--local for local k8s deployment.
-d/--delete to delete everything created.
--debug to debug everyline of code."""
  exit 1

elif [[  $2 == '--debug' ]]; then
  set -x

elif [ "$1" == '-t' ] || [ "$1" == '--terraform' ]; then
  provision-ec2s apply # we get three vars from that func: $master_ip $worker1_ip $worker2_ip
  if [ -z "$master_ip" ]; then
    echo "master_ip is empty"
    exit 1
  fi
  update_config_after_provision
  deployK8sRemotely

elif [ "$1" == '-l' ] || [ "$1" == '--local' ]; then
  update_config_after_provision
  deployK8sLocally

elif [ "$1" == '-d' ] || [ "$1" == '--delete' ]; then
  destroy_et
  exit 1

else
  echo """Invalid option. Use: 
-t/--terraform for remote k8s deployment.
-l/--local for local k8s deployment.
-d/--delete to delete everything created.
--debug to debug everyline of code."""
  exit 1
fi

sleep 15
# ----------------------------- execute playbook ----------------------------- #
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -e "ansible_user=${user_name}" -e "ansible_ssh_private_key_file=ansible/${key_name}.pem"
    # 1- copy & paste hosts to remote /etc/hosts
    # 2- copy & paste K8s_init.sh to remote home directory
    # 3- execute K8s_init.sh

# -------------- validate if the playbook executed successfully -------------- #
# # Check exit status
# if [ $? -eq 0 ]; then
#   clear
#   echo -e "The Cluster is Now Ready 🥳 🥳\n"
#   echo -e "Now ssh into the master node to check the cluster status\n"
#   sleep 2
ssh -i ansible/${key_name}.pem $user_name@$master_ip
# else
#     echo "Playbook execution failed."
# fi

# ------------ The following script is to get the cluster config_file from master to local. ------------ #
# master_ip=$(cat hosts | grep master | awk '{print $1}' | head -n 1)
# ssh -i $private_key_path $user_name@master_ip << EOF
# cat ~/.kube/config > remote.yaml
# EOF
# scp -i $private_key_path $user_name@master_ip:remote.yaml remote.yaml
# ------------------------------------------------------------------------------------------------------ #
