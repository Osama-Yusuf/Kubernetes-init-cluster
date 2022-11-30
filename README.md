# Initialize K8s Cluster with Bash, Ansible, AWS, & Terraform

## Usage:
```
./hostname.sh [OPTION]
   -y  Provision infra with terraform, else you will be prompted for ips, keys, etc.
   -d  Delete all files created by hostname.sh (ansible, inventory, etc.) else you will use them if they exist
Example: ./hostname.sh -y -d
```

### 'hostname.sh' provision 3 instances on aws with terraform then initialize the infrastructure using ansible playbooks:

### 1. Provisions 3 "t2.medium" ec2's using terraform
- #### Creates a key if not exists
- #### query default vpc & security group ids
- #### query ubuntu 20.04 ami in current region
- #### Then It creates 3 ec2's by for-looping these strings (master, worker1, worker2)

### 2. Then it initializes the cluster using bash script & ansible playbooks by:
- #### creating inventory file and hosts file to be copied to all nodes in the cluster 
- #### and install & initialize kubeadm & kubectl with k8s_init.sh script also copied to all nodes and then executed using ansible playbook
- #### then it creates kubeadm token file on the master node
- #### then it copies the token to the worker nodes and executes it
- #### after that the playbook apply the calico network plugin

### After execution 3 instances will be up & running on aws (master, worker1, & worker2) initialized with kubeadm & kubectl 
### Then it will ssh into master node for you to start working/studying k8s