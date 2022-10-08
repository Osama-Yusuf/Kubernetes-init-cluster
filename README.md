# Kubernetes init cluster

## Usage

```bash
bash hostname.sh
```

1. ### Provision infrastructure using terraform then initialize the infrastructure & running jenkins on master node as a contianer using ansible
   - #### Using script (k8s_init/hostname.sh) to provision 3 instances on aws then initialize the infrastructure using ansible using the following command:
      ```bash
      bash k8s_init/hostname.sh
      ```
   - #### After executing the script on your local machine you will get 3 instances on aws with the following names:
      - #### master
      - #### worker1
      - #### worker2
2. ### Now after we have the infrastructure and jenkins ready open jenkins console on your browser:
   ```
   http://<master_ip>:8080
   ```