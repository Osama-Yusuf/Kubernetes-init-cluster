destroy_et() {
  provision-ec2s destroy
  sed -i "s/${key_name}/KEY_NAME/g" terraform/variables.tf

  # Backup the original file
  # cp ansible/inventory.ini ansible/inventory.ini.bak
  rm -f ansible/token.sh 

  # Define placeholders
  placeholders="[all]\nMASTER_IP\nWORKER_01_IP\nWORKER_02_IP\n\n[master]\nMASTER_IP\n\n[worker]\nWORKER_01_IP\nWORKER_02_IP\n"

  # Replace content in inventory file
  echo -e "$placeholders" > ansible/inventory.ini

  sed -i -e 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\} master/MASTER_IP master/' \
       -e 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\} worker1/WORKER_01_IP worker1/' \
       -e 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\} worker2/WORKER_02_IP worker2/' nodes_config/etc_hosts.txt

  echo "config files updated with placeholders."
}