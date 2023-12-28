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
sudo usermod -aG docker $USER
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
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

# sudo kubeadm init --pod-network-cidr 192.168.0.0/16 --kubernetes-version v1.24.0
# sudo cp -if /etc/kubernetes/admin.conf $HOME/.kube/config && sudo chown -R ubuntu:ubuntu .kube/ && sudo chown $(id -u):$(id -g ) .kube/