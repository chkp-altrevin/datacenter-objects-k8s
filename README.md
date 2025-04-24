# Overview
What is this: Quick provisioning for Kubernetes integration with the Check Point Management server using SmartConsole, commonly referred as the CloudGuard Controller. Originally used for testing and demo purposes but feel free to use as you see fit. If you are interested in using helm or an orchestrator such as Rancher, you should check out the deployment options that are available from the official docs located [here](https://sc1.checkpoint.com/documents/R81/WebAdminGuides/EN/CP_R81_CloudGuard_Controller_AdminGuide/Topics-CGRDG/Supported-Data-Centers-Kubernetes.htm).

## Getting started
Assumes you already have a Check Point Management Server. The server that you will be running `k8s_controller_provisioning.sh` requires `kubectl` to be installed and a kube config located in the usual paths but don't worry the script will check as well.

- `chmod +x k8s_controller_provisioning.sh`

- `./k8s_controller_provisioning.sh`

- If you have any issues, check the log for clues.

## Optional Flags

```
Flag | Description
--deploy-cluster | Provisions a demo K3D cluster
--cluster-name <name> | (Optional) Name of the K3D cluster
--port <port> | (Optional) Kubernetes API port (default: 6550)
--install, --dry-run | Provision CloudGuard objects interactively or dry-run
--create-datacenter-object | Register to SmartConsole with API
```

### Importante

The flag `--create-datacenter-object` is a work in progress. 

k8s_controller_provisioning.sh --create-datacenter-object

Ensure you have the env vars setup:
```
export SMARTCENTER_USER=admin
export SMARTCENTER_PASS=secret
export SMARTCENTER_HOST=192.168.1.10
```
