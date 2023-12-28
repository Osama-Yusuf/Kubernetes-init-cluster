deployK8sRemotely(){
# make master and worker1 and worker2 without double quotes
  master_ip=$(echo $master_ip | tr -d '"')
  worker1_ip=$(echo $worker1_ip | tr -d '"')
  worker2_ip=$(echo $worker2_ip | tr -d '"')

  echo -e "\ninitializing kubernetes cluster"
  sleep 10 # wait till the ec2s to become fully ready and available

# ---------------------------------------------------------------------------- #
  # for loop into each node to set their hostname by these vars master_ip, worker1_ip, worker2_ip
  # then append them to hosts.txt file
  # then ssh to each node and set their hostname
  ips=("$master_ip" "$worker1_ip" "$worker2_ip")
  nodes=("master" "worker1" "worker2")
  for (( i=0 ; i<${#ips[@]} ; i++ ));
  do
    # scp -o StrictHostKeyChecking=no -i ansible/$key_name.pem nodes_config/k8s_init.sh $user_name@${ips[$i]}:~/
    ssh -o StrictHostKeyChecking=no -i ansible/$key_name.pem $user_name@${ips[$i]}  <<  EOF
    sudo hostnamectl set-hostname ${nodes[$i]}
EOF
  done
}