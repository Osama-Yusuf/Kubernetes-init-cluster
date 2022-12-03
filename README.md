# Kubernetes Init Cluster
**Kubernetes-init-cluster** is a **BASH** script that can be used to provision 3 instances on aws with bash & terraform then initialize the infrastructure using ansible playbooks.

You can take a look at the [GitHub project page](https://github.com/Osama-Yusuf/Kubernetes-init-cluster).

---

## Getting started:

### Prerequisites:
<!-- - [Terraform](https://www.terraform.io/downloads.html) -->
<!-- - [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) -->
<!-- - [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) -->
<!-- - [AWS Account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/) -->
- Terraform
   ```
   source <(curl -s https://raw.githubusercontent.com/Osama-Yusuf/Linux-Apps-Installation-Scripts/main/DevOps/terraform.sh)
   ```
- Ansible
   ```
   sudo apt-add-repository ppa:ansible/ansible
   sudo apt update
   sudo apt install ansible
   ```
- AWS CLI
   ```
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip
   sudo ./aws/install && rm -rf aws awscliv2.zip
   ```
- [AWS Account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/)
   - [Create an IAM User](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)
   - [Configure the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)

### Install:
```
git clone https://github.com/Osama-Yusuf/Kubernetes-init-cluster.git
cd Kubernetes-init-cluster && chmod +x hostname.sh 
```

### Usage:
```
./hostname.sh [OPTION]
   -y  Provision infra with terraform, else you will be prompted for ips, keys, etc.
   -d  Delete all files created by hostname.sh (ansible, inventory, etc.) else you will use them if they exist
Example: ./hostname.sh -y -d
```

---

## What it does:

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

---

## Tested Environments

* Ubuntu 20.04.

   If you have successfully tested this script on others systems or platforms please let me know!

---

## Support

 If you want to support this project, please consider donating:
 * PayPal: https://paypal.me/OsamaYusuf
 * Buy me a coffee: https://www.buymeacoffee.com/OsamaYusuf
 * ETH: 0x507bF8931b534a81Ced18FDf8fc5BE4Daf08332B

---

* `By Osama-Yusuf`
* `Thanks for reading`

-------
##### Report bugs for "Git-Repo-Pusher"
* `osama9mohamed5@gmail.com`