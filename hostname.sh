#!/bin/bash

# This script creates 6 files in the current directory after the script is executed it deletes them.
# 1. hosts - contains the list of ip and hostname and to be copied to each node /etc/hosts with ansible playbook
# 2. hosts.txt - contains the list of ip and credentials for ansible to ssh to each node
# 3. ansible.cfg - contains rules for easier execution for ansible
# 4. k8s_init.sh - contains the list of commands to be executed on all nodes to initialze the cluster
# 5. playbook.yml - ansible playbook to to copy hosts file to each node and execute k8s_init.sh
# 6. token.sh - contains the command to get the token to join the cluster created by kubeadm init from master node

# ---------------------- provision ec2's with terraform -------------------------------------------- #
terra(){
  cd terraform
  # --------------------------------- Key Pair --------------------------------- #
  # check if there's a key pair in the region if not it creates one 
  aws ec2 describe-key-pairs --region eu-central-1 --query 'KeyPairs[*].KeyName' >/dev/null || aws ec2 create-key-pair --key-name $USER-key --region eu-central-1 --query 'KeyMaterial' --output text > $USER-key.pem 

  # check if there's any key pair in the same directory
  if ( ! ls | grep ".pem" >/dev/null); then
      echo "There's a key pair in current region, Please copy the key.pem to terraform directory"
      exit 1
  fi
  # ---------------------------------------------------------------------------- #

  # ------------------------------- creates vars ------------------------------- #
  vpc_id=$(aws ec2 describe-vpcs --region eu-central-1 --query 'Vpcs[*].VpcId' | grep "vpc-" | sed 's/ //g')
  vpc_sg_id=$(aws ec2 describe-security-groups --region eu-central-1 --query 'SecurityGroups[*].GroupId' | grep "sg-" | sed 's/ //g')
  key_pair="\"$(ls | grep ".pem" | sed "s/.pem//")\""
  ubuntu_ami=$(aws ec2 describe-images --region eu-central-1 --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*" --query 'Images[*].ImageId' | grep "ami-" | sed 's/ //g' | sort -u | awk 'NR==20' | sed 's/,//g')
  # ubuntu_ami=$(aws ec2 describe-images --region eu-central-1 --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*" --query 'Images[*].ImageId' | grep "ami-" | sed 's/ //g' | sed 's/"//g')
  # ubuntu_ami="\"$(aws ec2 describe-images --region eu-central-1 --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-*" --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)\""
  # ---------------------------------------------------------------------------- #

  # if you've added a variable to the script above make sure to delete the main.env file before running the script

  # ------------ check if there's a .env file if not it creates one ------------ #
  if ( ! ls | grep ".env" >/dev/null); then
  cat <<EOF > main.env
  export TF_VAR_vpc_id=$vpc_id
  export TF_VAR_vpc_sg_id=$vpc_sg_id
  export TF_VAR_key_pair=$key_pair
  export TF_VAR_ubuntu_ami=$ubuntu_ami
EOF
  fi
  # ---------------------------------------------------------------------------- #

  # ------------- source .env file then execute terraform commands ------------- #
  source main.env
    # check if terraform is initialized
  if [ ! -d ".terraform" ]; then
      terraform init
  fi
  # terraform refresh # ----- for checking output vars while testing
  terraform plan
  terraform apply -auto-approve
  # ---------------------------------------------------------------------------- #

  # --------------- getting the public ip address of all instance -------------- #
  master_ip=$(terraform output master_public_ip)
  worker1_ip=$(terraform output worker1_public_ip)
  worker2_ip=$(terraform output worker2_public_ip)
  echo
  echo "master node ip is: $master_ip"
  echo "worker1 node ip is: $worker1_ip"
  echo "worker2 node ip is: $worker2_ip"
  # ---------------------------------------------------------------------------- #
  cd ..
}
# -------------------------------------------------------------------------------------------------- #

# read -p "Do you want to provision ec2's (Y/N): " answer
# if [ $answer == "Y" ]; then
  # terra
# fi

if [ $# -eq 0 ]; then
    echo
    # echo "No argument supplied"
elif [ $1 == '-y' ] || [ $2 == '-y' ]; then
  echo
  terra
else 
  echo
fi

check_exist(){

user_name="ubuntu"

# -------------- contains rules for easier execution for ansible ------------- #
cat <<EOF | tee ansible.cfg
[defaults]
host_key_checking = false
allow_world_readable_tmpfiles = True
pipelining = True
EOF

# ---------------------------------------------------------------------------- # k8s_init.sh # ---------------------------------------------------------------------------- #

cat <<EOT | tee k8s_init.sh
#!/bin/bash

# enable kernal modules by adding the following the containerd configuration file 
cat << EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

# then enable the modules by running the following command
sudo modprobe overlay
sudo modprobe br_netfilter

# set up system level configuration related to network traffic forwarding
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# apply the configuration by running the following command
sudo sysctl --system

# install containerd
sudo apt update && sudo apt install -y containerd docker.io

# configure containerd
sudo mkdir -p /etc/containerd

# generate the default configuration file & save it to /etc/containerd/config.toml
sudo containerd config default | sudo tee /etc/containerd/config.toml

# restart containerd to make sure the changes take effect
sudo systemctl restart containerd

# add current user to docker group in order to run docker without sudo
# sudo usermod -aG docker $USER
# logout and login again to apply changes
# newgrp docker

# kubernetes requires swap to be disabled
sudo swapoff -a

# install dependencies
sudo apt-get update && sudo apt-get install -y apt-transport-https curl

# add the GPG key for the official Kubernetes repository
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

# add the Kubernetes repository
cat << EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# update packages and install kubelet, kubeadm & kubectl
sudo apt-get update && sudo apt-get install -y kubelet=1.24.0-00 kubeadm=1.24.0-00 kubectl=1.24.0-00

# hold the version of kubelet, kubeadm & kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# this is to bypass the error: "kubeadm init: error execution phase preflight: [preflight] Some fatal errors occurred:
echo 1 > /proc/sys/net/ipv4/ip_forward

EOT
# ---------------------------------------------------------------------------- # k8s_init.sh # ---------------------------------------------------------------------------- #
chmod +x k8s_init.sh 

no_terra(){
  # ------------------ print default hosts file to append upon ----------------- #
  cat <<EOF | tee hosts
  127.0.0.1 localhost

  # The following lines are desirable for IPv6 capable hosts
  ::1 ip6-localhost ip6-loopback
  fe00::0 ip6-localnet
  ff00::0 ip6-mcastprefix
  ff02::1 ip6-allnodes
  ff02::2 ip6-allrouters
  ff02::3 ip6-allhosts

EOF

  # ------ print inital hosts.txt file to appen upon for ansible playbook ------ #
  cat <<EOF | tee hosts.txt
  [all]
EOF

  clear

  read -p "Please enter the path to the private key (.pem file): " private_key_path

  # ------ get the number of nodes then loop through them to get their private ip and hostname ------ #
      # then append them to hosts.txt file
      # then ssh to each node and set their hostname
  read -p "Please enter the number of all your nodes (worker and master) : " node_number
  echo 

  # ----------- create a for loop to add all nodes to /etc/hosts file ---------- #
  for (( i=1 ; i<=$node_number ; i++ )); 
  do
      read -p "Please enter the public ip of node $i : " node_public_ip
      read -p "Please enter the hostname of node $i : " node_hostname
      # ----------------- temporary comment the following line ----------------- #
      scp -o StrictHostKeyChecking=no -i $private_key_path k8s_init.sh $user_name@$node_public_ip:~/
      echo "$node_public_ip $node_hostname" >> hosts
      echo "$node_public_ip" >> hosts.txt
      # ----------------- temporary comment the following 3 lines ----------------- #
      ssh -o StrictHostKeyChecking=no -i $private_key_path $user_name@$node_public_ip << EOF
      sudo hostnamectl set-hostname $node_hostname
EOF
      clear
      echo "done"
      echo
  done

  # ------------- complete the hosts.txt file for ansible playbook ------------- #
  tee -a hosts.txt > /dev/null <<EOT

  [all:vars]
  ansible_ssh_private_key_file=$private_key_path
  ansible_user=$user_name

EOT

  # -------------------------------- master ips -------------------------------- #
  tee -a hosts.txt > /dev/null <<EOT
  [master]
EOT

  cat hosts | grep master | awk '{print $1}' >> hosts.txt

  tee -a hosts.txt > /dev/null <<EOT

  [master:vars]
  ansible_ssh_private_key_file=$private_key_path
  ansible_user=$user_name

EOT

  # -------------------------------- worker ips -------------------------------- #
  tee -a hosts.txt > /dev/null <<EOT
  [worker]
EOT

  cat hosts | grep worker | awk '{print $1}' >> hosts.txt

  tee -a hosts.txt > /dev/null <<EOT

  [worker:vars]
  ansible_ssh_private_key_file=$private_key_path
  ansible_user=$user_name

EOT
}

with_terra(){
  key_pair=$(echo $key_pair | tr -d '"')
  private_key_path="terraform/$key_pair.pem"

# make master and worker1 and worker2 without double quotes
  master_ip=$(echo $master_ip | tr -d '"')
  worker1_ip=$(echo $worker1_ip | tr -d '"')
  worker2_ip=$(echo $worker2_ip | tr -d '"')

  cat <<EOF | tee hosts
  127.0.0.1 localhost

  # The following lines are desirable for IPv6 capable hosts
  ::1 ip6-localhost ip6-loopback
  fe00::0 ip6-localnet
  ff00::0 ip6-mcastprefix
  ff02::1 ip6-allnodes
  ff02::2 ip6-allrouters
  ff02::3 ip6-allhosts

  $master_ip master
  $worker1_ip worker1
  $worker2_ip worker2

EOF
  
  cat <<EOF | tee hosts.txt
  [all]
  $master_ip
  $worker1_ip
  $worker2_ip

  [all:vars]
  ansible_ssh_private_key_file=$private_key_path
  ansible_user=$user_name

  [master]
  $master_ip

  [master:vars]
  ansible_ssh_private_key_file=$private_key_path
  ansible_user=$user_name

  [worker]
  $worker1_ip
  $worker2_ip

  [worker:vars]
  ansible_ssh_private_key_file=$private_key_path
  ansible_user=$user_name
EOF

clear
echo "initializing kubernetes cluster"
sleep 7

# ---------------------------------------------------------------------------- #
  # for loop into each node to set their hostname by these vars master_ip, worker1_ip, worker2_ip
  # then append them to hosts.txt file
  # then ssh to each node and set their hostname
  ips=("$master_ip" "$worker1_ip" "$worker2_ip")
  nodes=("master" "worker1" "worker2")
  for (( i=0 ; i<${#ips[@]} ; i++ ));
  do
    scp -o StrictHostKeyChecking=no -i $private_key_path k8s_init.sh $user_name@${ips[$i]}:~/
    ssh -o StrictHostKeyChecking=no -i $private_key_path $user_name@${ips[$i]}  <<  EOF
    sudo hostnamectl set-hostname ${nodes[$i]}
EOF
  done
# ---------------------------------------------------------------------------- #
}

# check if master_ip has value
if [ -z "$master_ip" ]; then
  echo "master_ip is empty"
  no_terra
else
  echo "master_ip is not empty"
  with_terra
fi


# ------------------------ print out the playbook.yml ------------------------ #
tee -a playbook.yml > /dev/null <<EOT
---
- name: initialize cluster.
  hosts: all
  become: yes
  become: yes
  become: true
  become_method: sudo
  become_user: root

  tasks:
    - name: Transfer the hosts file to /etc/hosts in all nodes
      become: yes
      become: true
      become_method: sudo
      become_user: root
      copy:
        src: hosts
        dest: /etc/hosts
        owner: root
        group: root
        mode: u=rw,g=x,o=x
        backup: yes

    - name: Execute k8s_init.sh script on all nodes
      become: yes
      become: true
      become_method: sudo
      become_user: root
      command: sudo bash k8s_init.sh

- name: Download kubeadm Token from Master to local machine.
  hosts: master
  tasks:
    - name: initalize master & create kubeadm token
      shell: |
        # initialize the cluster
        sudo kubeadm init --pod-network-cidr 192.168.0.0/16 --kubernetes-version v1.24.0
        # set up local kubeconfig for kubectl to be able to communicate with the cluster
        sudo cp /etc/kubernetes/admin.conf /home/$user_name/config
        # copy the admin kubeconfig file to the local kubeconfig file path
        # then set the ownership of the local kubeconfig file to the current user to avoid the need to use sudo
        mkdir /home/$user_name/.kube
        mv /home/$user_name/config /home/$user_name/.kube/config
        sudo chown $(id -u):$(id -g ) /home/$user_name/.kube/config
        sudo kubeadm token create --print-join-command > /home/$user_name/token.sh
        echo "make sure to add port 6443 to the security group of the master node (if using aws instance)"
        rm -f k8s_init.sh

    - name: Fetch token.sh from master node
      fetch:
        src: /home/$user_name/token.sh
        dest: token.sh
        flat: yes
        mode: u=rwx,g=x,o=x

- name: Copy token to all worker nodes and execute it.
  hosts: worker
  tasks:
    - name: Transfer the token to all worker nodes
      copy:
        src: token.sh
        dest: /home/$user_name/token.sh
        mode: u=rwx,g=x,o=x
        backup: yes
    - name: Execute the token
      command: sudo bash /home/$user_name/token.sh && rm -f /home/$user_name/token.sh

- name: Run the yaml networking script to initialize the cluster. 
  hosts: master
  tasks:
    - name: init k8s cluster
      shell: | 
        kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
        rm -f /home/$user_name/token.sh

- name: add user to docker group 
  hosts: master
  tasks:
    - name: add user to docker group
      shell: |
        sudo usermod -aG docker $user_name
        newgrp docker && exit

EOT

# ----------------------------- execute playbook ----------------------------- #
ansible-playbook -i hosts.txt playbook.yml
    # 1- copy & paste hosts to remote /etc/hosts
    # 2- copy & paste K8s_init.sh to remote home directory
    # 3- execute K8s_init.sh

}
# ------------------ for checking on exsiting vars with arg ------------------ #

#  check if hosts.txt & hosts & playbook.yml & k8s_init.sh & token.sh exist
if [ -f hosts.txt ] && [ -f hosts ] && [ -f terraform/main.env ] || [ -f playbook.yml ] || [ -f k8s_init.sh ] || [ -f token.sh ]; then
  # check if hosts.txt & hosts & playbook.yml & k8s_init.sh & token.sh exist
    # but most importantly check if hosts.txt, hosts, & terraform/main.env exist
  # then check if arg is -d if so delete all files and start from scratch
  if [ $# -eq 0 ]; then
    echo
    # echo "No argument supplied"
    # echo "Continueing with existing files"
  elif [ $1 == '-d' ] || [ $2 == '-d' ]; then
    # terra
    echo "starting from scratch"
    rm -f hosts hosts.txt ansible.cfg playbook.yml k8s_init.sh token.sh terraform/main.env terraform/.terraform terraform/.terraform.lock.hcl terraform/terraform.tfstate terraform/terraform.tfstate.backup terraform/terraform.tfvars
    check_exist
  else 
    echo
    # echo "Continueing with existing files"
    ansible-playbook -i hosts.txt playbook.yml
  fi

else
    echo "starting from scratch"
    rm -f hosts hosts.txt ansible.cfg playbook.yml k8s_init.sh token.sh
    check_exist
fi

# if there's any issues with ansible or want to chech the playbook output for longer remove the below command(clear)
clear
echo "The Cluster is Now Ready 🥳 🥳"
echo
echo "Now ssh into the master node to check the cluster status"
sleep 2
echo
ssh -i $private_key_path $user_name@$master_ip

# ------------ The following script is to get the cluster config_file from master to local. ------------ #
# master_ip=$(cat hosts | grep master | awk '{print $1}' | head -n 1)
# ssh -i $private_key_path $user_name@master_ip << EOF
# cat ~/.kube/config > remote.yaml
# EOF
# scp -i $private_key_path $user_name@master_ip:remote.yaml remote.yaml
# ------------------------------------------------------------------------------------------------------ #
