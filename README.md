# Platform Engineering Lab

This repository contains resources and code for the [Platform Engineering course](https://github.com/timebertt/talk-platform-engineering) at DHBW Mannheim.

## Prerequisites

As a student, you should have the following knowledge and skills for this course:

- Familiarity with the command line and basic terminal commands
- Understanding of running and building containers with Docker
- Understanding of Kubernetes core concepts (e.g., pods, services, deployments)
- Interacting with Kubernetes clusters using `kubectl`

To prepare for the practical exercises in this course, ensure you have the following set up:

- Access to the DHBW network (e.g., via VPN)
- A local command line terminal (Linux, macOS, or Windows with WSL)
- A Code editor (e.g., [Visual Studio Code](https://code.visualstudio.com/))
- [Docker Desktop](https://docs.docker.com/get-docker/) (or comparable alternatives)
  - optional: [kind](https://kind.sigs.k8s.io/) for running local Kubernetes clusters
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) installed
  - optional: [k9s](https://k9scli.io/) installed for easier cluster navigation
- GitHub account (for creating individual repositories for exercises)
- Git installed and authenticated with your GitHub account
  - optional: visual Git client (e.g., GitHub Desktop, Sourcetree)
- optional: SSH client (e.g., OpenSSH, PuTTY)

## Cluster Setup

Each student receives an individual Kubernetes cluster for practical exercises during the course.
The clusters are not set up for production use but provide a hands-on environment to gain more in-depth experience with Kubernetes and the cloud-native toolkit.

The clusters are provisioned using the [OpenTofu](https://opentofu.org/) configuration in this repository (see the [cluster module](tofu/cluster/)) as follows:

- **Kubernetes Distribution:** [k3s](https://k3s.io/) (lightweight Kubernetes, simple to set up)
- **Cloud Platform:** Deployed on the [DHBW Cloud](https://dhbw.cloud/), a private OpenStack-based environment
- **Cluster Topology:**
  - 1 control plane node (k3s server)
    - runs cluster management components (e.g., API server, controller manager, scheduler)
    - excluded from scheduling workloads by default
    - excluded from handling LoadBalancer traffic
  - 3 worker nodes (k3s agent)
    - available for scheduling workloads
    - handle LoadBalancer traffic
- **Networking:**
  - Each node receives an external IP address
  - The control plane node exposes the Kubernetes API server via its external IP address
  - Each node can be accessed via SSH on its external IP address (port 22) using the cluster-specific private key (use the image's default user, e.g.,
    `ubuntu` for Ubuntu)
  - Access to the cluster, nodes, and workload is only possible within the DHBW network (e.g., via VPN)
- **Load Balancers:**
  - [Services of type `LoadBalancer`](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer) are implemented using the built-in [k3s
    `servicelb` controller](https://docs.k3s.io/networking/networking-services#service-load-balancer)
  - It does not provision external cloud load balancers but runs a simple [iptables-based proxy](https://github.com/k3s-io/klipper-lb) on each worker node to forward traffic to the appropriate service
  - See limitations below
- **Persistent Volumes:**
  - `PersistentVolumes` are provisioned by the [local-path-provisioner](https://docs.k3s.io/storage#setting-up-the-local-storage-provider)
  - All persistent data is stored on a single data disk attached to each node
  - No external OpenStack block storage is provisioned individually per `PersistentVolumes`
  - See limitations below
- **Cluster Access:**
  - Students receive a `kubeconfig.yaml` file for accessing their cluster
  - SSH access to the nodes is possible using a private key provided in the `secrets` directory

### Limitations

- no high availability for control plane node
- static cluster bootstrapping configuration, i.e., no cluster autoscaling or automatic node management
- Services of type `LoadBalancer` must use distinct ports, e.g., only one LoadBalancer for port 443 is possible
- Ports allowed for LoadBalancers: 80, 443, 12000-12999 (configured in [security group rules](tofu/cluster/network.tf))
- `PersistentVolumes` are local to each node and cannot be shared or moved across nodes, i.e., pods using an existing `PersistentVolumes` cannot be rescheduled to other nodes

## Contributions Welcome

If you spot any bugs or have suggestions for improvements of the course materials or cluster setup, feel free to open an issue or a pull request!
