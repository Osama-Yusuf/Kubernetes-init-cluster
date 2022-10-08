#!/bin/bash

# this script creates 5 files 
# 1. hosts - contains the list of ip and hostname and to be copied to each node /etc/hosts with ansible playbook
# 2. hosts.txt - contains the list of ip and credentials for ansible to ssh to each node
# 3. ansible.cfg - contains rules for easier execution for ansible
# 4. k8s_init.sh - contains the list of commands to be executed on all nodes to initialze the cluster
# 5. playbook.yml - ansible playbook to to copy hosts file to each node and execute k8s_init.sh

read -p "Do you want to provision ec2's (Y/N): " user_name

terra(){
  # check if terraform is initialized
  cd terraform
  if [ ! -d ".terraform" ]; then
      terraform init
  fi
  terraform plan
  terraform apply -auto-approve
  cd ..
}

if [ $user_name == "Y" ]; then
  terra
fi

# -------------- contains rules for easier execution for ansible ------------- #
cat <<EOF | tee ansible.cfg
[defaults]
host_key_checking = false
allow_world_readable_tmpfiles = True
pipelining = True
EOF

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
read -p "Please enter the username of all nodes (for Ex. 'ubuntu'): " user_name

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
# sudo usermod -aG docker $user_name
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

clear
chmod +x k8s_init.sh 

# ------------- complete the hosts.txt file for ansible playbook ------------- #
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
    scp -i $private_key_path k8s_init.sh $user_name@$node_public_ip:~/
    echo "$node_public_ip $node_hostname" >> hosts
    echo "$node_public_ip" >> hosts.txt
    # ----------------- temporary comment the following 3 lines ----------------- #
    ssh -i $private_key_path $user_name@$node_public_ip << EOF
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

rm -f hosts hosts.txt ansible.cfg playbook.yml k8s_init.sh token.sh

echo "The Cluster is Now Ready 🥳 🥳"

# ------------ The following script is to get the cluster config_file from master to local. ------------ #
# master_ip=$(cat hosts | grep master | awk '{print $1}' | head -n 1)
# ssh -i $private_key_path $user_name@master_ip << EOF
# cat ~/.kube/config > remote.yaml
# EOF
# scp -i $private_key_path $user_name@master_ip:remote.yaml remote.yaml
# ------------------------------------------------------------------------------------------------------ #
