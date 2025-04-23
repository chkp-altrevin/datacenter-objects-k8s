# cgns-controller-k8s

## Getting started

- `chmod +x k8s_controller_provisioning.sh`

- `./k8s_controller_provisioning.sh`

- If you have any issues, check the log for clues.

## Optional Flags

```
Usage: ./k8s_controller_provisioning.sh [OPTIONS]

Options:
  --help                         Show this help message and exit
  --uninstall                    Remove all created Kubernetes objects
  --create-datacenter-object     Register the cluster in SmartConsole using the API

This script provisions a Kubernetes cluster for integration with Check Point CloudGuard.
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
