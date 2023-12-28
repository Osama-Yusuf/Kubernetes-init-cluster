deployK8sLocally(){
  # ------ get the number of nodes then loop through them to get their private ip and hostname ------ #
      # then append them to hosts.txt file
      # then ssh to each node and set their hostname
  awk '/^\[all\]/ {flag=1; next} /^\[/ && !/^\[all\]/ {flag=0} flag && NF' ../inventory.ini | wc -l

  # ----------- create a for loop to add all nodes to /etc/hosts file ---------- #
  for (( i=1 ; i<=$node_number ; i++ )); 
  do
      read -p "Please enter the public ip of node $i : " node_public_ip
      read -p "Please enter the hostname of node $i : " node_hostname
      # ----------------- temporary comment the following line ----------------- #
      scp -o StrictHostKeyChecking=no -i ../ansible/$key_name.pem k8s_init.sh $user_name@$node_public_ip:~/
      echo "$node_public_ip $node_hostname" >> hosts
      echo "$node_public_ip" >> hosts.txt
      # ----------------- temporary comment the following 3 lines ----------------- #
      ssh -o StrictHostKeyChecking=no -i ../ansible/$key_name.pem $user_name@$node_public_ip << EOF
      sudo hostnamectl set-hostname $node_hostname
EOF
      echo "done"
      echo
  done
}