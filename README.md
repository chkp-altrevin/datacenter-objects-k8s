# Overview
What is this: Quick provisioning for Kubernetes integration with the Check Point Management server using SmartConsole, commonly referred as the CloudGuard Controller. Originally used for testing and demo purposes but feel free to use as you see fit. If you are interested in using helm or an orchestrator such as Rancher, you should check out the deployment options that are available from the official docs located [here](https://sc1.checkpoint.com/documents/R81/WebAdminGuides/EN/CP_R81_CloudGuard_Controller_AdminGuide/Topics-CGRDG/Supported-Data-Centers-Kubernetes.htm).

## Getting started
Assumes you already have a Check Point Management Server. The server that you will be running `k8s_controller_provisioning.sh` requires `kubectl` to be installed and a kube config located in the usual paths but don't worry the script will check as well.

- `chmod +x k8s_controller_provisioning.sh`
- Optional env vars you can customize located in `k8s_controller_provisioning.sh` but not required.
- `./k8s_controller_provisioning.sh --install`
- If you have any issues, check the log for clues.

## Usage | Flags
```
Usage:  [OPTIONS]

Options:
  --help                         Show this help message and exit
  --install                      Install CloudGuard objects on the cluster
  --uninstall                    Remove all created Kubernetes objects
  --create-datacenter-object     Register the cluster in SmartConsole using the API
  --dry-run                      Simulate actions without applying changes

This script provisions a Kubernetes cluster for integration with Check Point CloudGuard.
```
### Importante

The flag `--create-datacenter-object` is a work in progress mileage will vary. 

k8s_controller_provisioning.sh --create-datacenter-object

Ensure you have the env vars setup:
```
export SMARTCENTER_USER=admin
export SMARTCENTER_PASS=secret
export SMARTCENTER_HOST=192.168.1.10
```
