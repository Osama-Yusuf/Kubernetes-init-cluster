# provision or destroy ec2's with terraform
provision-ec2s(){
  action=$1

  cd terraform
  case $action in
    apply)
      # chmod +x nodes_config/k8s_init.sh
      sed -i "s/KEY_NAME/${key_name}/g" variables.tf
      # Check if Terraform is initialized
      if [ ! -d ".terraform" ]; then
          terraform init
      fi
      # Apply Terraform configuration
      if terraform validate; then
        if terraform apply --auto-approve; then
          chmod 400 $key_name
          cp -f $key_name ../ansible/$key_name.pem
          # Getting the public IP address of all instances
          master_ip=$(terraform output master_public_ip)
          worker1_ip=$(terraform output worker1_public_ip)
          worker2_ip=$(terraform output worker2_public_ip)
          echo -e "\nmaster node ip is: $master_ip"
          echo "worker1 node ip is: $worker1_ip"
          echo -e "worker2 node ip is: $worker2_ip\n"
        else
          echo "Terraform apply failed"
          exit 1
        fi
      else
        echo "Terraform validation failed"
        exit 1
      fi
      ;;
    destroy)
      # Destroy Terraform managed infrastructure
      if terraform destroy --auto-approve; then
        echo "Infrastructure successfully destroyed"
        
        # Delete the key file after destroying infrastructure
        # rm -fr ansible/$key_name.pem .terraform* terraform.tf*
        rm -fr ../ansible/$key_name.pem

        echo "Key file deleted"
      else
        echo "Terraform destroy failed"
        exit 1
      fi
      ;;
    *)
      echo "Invalid action. Use 'apply' or 'destroy'."
      exit 1
      ;;
  esac
  cd ..
}

if [[ $1 == "destroy" ]]; then
  provision-ec2s destroy
elif [[ $1 == "apply" ]]; then
  provision-ec2s apply
fi