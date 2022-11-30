# Kubernetes init cluster
## Initialize k8s cluster with bash, ansible, AWS, & terraform
## first it provisions the infra using terraform
## then it initializes the cluster using bash script & ansible playbooks by:
- ## creating inventory file and hosts file to be copied to all nodes in the cluster 
- ## and install & initialize kubeadm & kubectl with k8s_init.sh script also copied to all nodes and then executed using ansible playbook
## Usage:
```
./hostname.sh [OPTION]
   -y  Provision infra with terraform, else you will be prompted for ips, keys, etc.
   -d  Delete all files created by hostname.sh (ansible, inventory, etc.) else you will use them if they exist
Example: ./hostname.sh -y -d
```
### "hostname.sh" provision 3 instances on aws with terraform then initialize the infrastructure using ansible playbooks
#### After execution 3 instances will be up & running on aws (master, worker1, & worker2) initialized with kubeadm & kubectl finally the script will ssh into master node for you to start working/studying k8s