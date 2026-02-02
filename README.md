# HomeLab

This repo holds code for my HomeLab. I am in the process of learning Kubernetes, GitOps, and Linux as I transition to DevOps and there is no better way than to have a hands on experience. 

### Hardware

<img width="1280" height="960" alt="image" src="https://github.com/user-attachments/assets/d9e7abdb-89a0-47ca-9fee-3ea338af9414" />


The Kubernetes cluster is a 2-node setup with **hpmini01** (control plane node) and **hpmini02** (worker node), both running on second market cute mini tiny PC [HP EliteDesk 705 G2 Mini](https://milanoidx.substack.com/p/homelab-the-hardware) (CPU AMD A8-8600B 15W TDP, 8GB RAM, 128G SSD). I picked these because of their low power consumption and affordability. They sit below TV set alongside with Sony Playstation 4 and yet another mini PC with [Batocera](https://batocera.org/) Linux.

### Operating System

Ubuntu 24 LTS.

### Kubernetes cluster

The machine has installed [K3s](https://k3s.io/). It is an easy-to-use, lightweight Kubernetes distribution.

### Flux CD (GitOps)

With Flux CD, managing the cluster and deploying applications is driven by git changes. No need to run `kubectl` commands manually. Push a change to the git repository and Flux will take care of the rest.

### Hosted apps

- Linkding (bookmark manager) https://lkd.milanoid.net/
- Audiobookshelf https://audiobooks.milanoid.net/
- Webhosting https://web.milanoid.net/
- Pi-hole (pihole.milanoid.net - LAN/VPN only)
