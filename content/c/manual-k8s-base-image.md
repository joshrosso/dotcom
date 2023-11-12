---
title: Kubernetes Base Images for qemu/kvm/libvirt
weight: 9100
description: Creating base images for Kubernetes that can work in the qemu/kvm/libvirt stack (qcow2)
date: 2023-09-17
draft: true
aliases:
---

# Kubernetes Base Images for qemu/kvm/libvirt

This guide demonstrates manual creation of a machine image for Kubernetes.
It's an expansion on a prior guide, [Preparing Machine Images for
qemu/KVM](https://joshrosso.com/c/machine-images). This guide will give you
perspective on how a base image is composed, however, you're more likely to
encapsulate these steps into tools like [HashiCorp's
Packer](https://www.packer.io).

## Base Image Composition

The base image will contain:

* Operating system: [Ubuntu 22.04](https://releases.ubuntu.com/jammy)
* OS Packages:
    * Supporting items: [apt-transport-https](https://manpages.ubuntu.com/manpages/focal/en/man1/apt-transport-https.1.html), [ca-certificates](https://packages.debian.org/sid/ca-certificates), [curl](https://packages.debian.org/sid/curl)
    * Kubernetes: [kubelet](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/), [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm), [kubectl](https://kubernetes.io/docs/reference/kubectl)
    * Container runtime: [cri-o](https://github.com/cri-o/cri-o), [cri-o-runc](https://github.com/opencontainers/runc) [cri-tools](https://github.com/kubernetes-sigs/cri-tools)
* Kubernetes container images: [coredns](https://coredns.io), [etcd](https://etcd.io/), [kube-apiserver](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver),
  [kube-controller-manager](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/), [kube-proxy](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/), [kube-scheduler](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-scheduler/), [pause](https://www.ianlewis.org/en/almighty-pause-container).

## Base Image Assumptions

The base image will:

* Have no [machine-id](https://man7.org/linux/man-pages/man5/machine-id.5.html).
    * Thus it will generate one on boot. This ID will be used when reaching out
      to DHCP to get an IP, ensuring each VM created gets a unique IP.
* Set its hostname to its IP.
    * A machine assigned the IP `192.168.1.151` will have its hostname set to
      `192-168-1-151`.

The image format will be [qcow2](https://en.wikipedia.org/wiki/Qcow) and used in
a kvm/libvirt/qemu, which is what runs my homelab.

## Creating a New Image

First step is to create an image file and install the operating system to it
using an ISO. These steps will assume you're performing them on the hypervisor.

> This guide will assume your hypervisor is exposing a bridge (`br0`) interface
> for VMs to attach to. See [VM Networking ( Libvirt / Bridge )](https://joshrosso.com/c/vm-networks/) for details.

1. Download the Ubuntu ISO.

    ```sh
    wget https://mirrors.mit.edu/ubuntu-releases/22.04/ubuntu-22.04.3-live-server-amd64.iso \
         -O /var/lib/libvirt/isos/ubuntu-22.04.3.iso
    ```
    
    > The file destination `/var/lib/libvirt/isos` is a directory I create on my
    > hypervisors to store local ISO copies.

1. Create the image file and VM:

    ```sh
    #!/bin/sh

    # location to store the base image
    PATH_IMG=/var/lib/libvirt/images
    NAME=k8s-base
    # where to pickup the ISO file for "cdrom" mount.
    PATH_ISO=/var/lib/libvirt/isos/ubuntu-22.04.3.iso

    # create the qcow image first, with a max size of 100GB.
    #
    # note: this is thinly provisioned, meaning the file only uses
    #       what it needs.
    qemu-img create -f qcow2 ${PATH_IMG}/${NAME}.qcow2 100G

    # start the VM and expose the console at vnc://${HYPERVISOR_IP}:5977
    # with a password of foobar.
    #
    # note: osinfo will attempt to [auto]detect and if it cannot work
    #       fallback to ubuntujammy. You can change the fallback value
    #       by finding the appropriate OS in `virt-install --osinfo list`.
    virt-install \
      --name ${NAME} \
      --osinfo detect=on,name=ubuntujammy \
      --ram 5000 \
      --disk=${PATH_IMG}/${NAME}.qcow2 \
      --vcpus 2 \
      --bridge=br0 \
      --graphics=vnc,password=foobar,port=5977,listen=0.0.0.0 \
      --autoconsole none \
      --cdrom=${PATH_ISO} \
      --boot uefi
    ```

1. Open a VNC viewer and complete the installation.

    Linux has multiple viewers available. On Mac, a viewer is built into the OS.
    You can access the VM's console by heading over to
    vnc://${HYPERVISOR_IP}:5977 in a browser.

    < IMAGE HERE >
    <img src="">

    A few items to note during the install:

    1. The server's name does not matter; it'll be removed eventually.
    1. You likely want to enable OpenSSH, which is an option in the installer.

## Installing OS Packages

Next we install OS packages used in running Kubernetes on each node.

1. SSH into the VM.

1. Install the packages.

    ```sh
    #!/bin/sh

    ###################
    # General Packages
    ###################
    apt update
    apt install apt-transport-https ca-certificates curl gnupg2 software-properties-common -y

    ####################################
    # Container Runtime (crio) Packages
    ####################################
    OS=xUbuntu_22.04
    CRIO_VERSION=1.24

    echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /"| sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
    echo "deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/$OS/ /"|sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.list
    curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/$OS/Release.key | sudo apt-key add -
    curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo apt-key add -

    apt update
    apt install cri-o cri-o-runc -y

    systemctl enable crio
    systemctl start crio

    ######################
    # Kubernetes Packages
    ######################
    sudo apt-get install -y apt-transport-https ca-certificates curl
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl

    #########################
    # Enable IPv4 Forwarding
    #########################
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOF

    modprobe overlay
    modprobe br_netfilter

    # sysctl params required by setup, params persist across reboots
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOF

    # Apply sysctl params without reboot
    sysctl --system

    ############################
    # Preload Kubernetes Images
    ############################

    kubeadm config images pull -v=5
    ```

## Automating hostname Creation

Since we'll be stamping out VMs, each new VM that comes up needs a unique
hostname. Similar to AWS, a clean solution would be to assign the VM's hostname
to the IP address by default.

1. Add this script to `/usr/local/bin/init-hostname`.

    ```sh
    #!/bin/sh
    SN="init-hostname"

    # do nothing if /etc/hostname exists
    if [ -f "/etc/hostname" ]; then
              echo "${SN}: /etc/hostname exists; noop"
              exit
    fi

    echo "${SN}: creating hostname"

    # set hostname
    hostnamectl set-hostname $(ip -o -4 addr show | awk '!/ lo | docker[0-9]* /{ sub(/\/.*/, "", $4); gsub(/\./, "-", $4); print $4 }')

    # sort of dangerous, but works.
    if [ -f "/etc/hostname" ]; then
              /sbin/reboot
    fi
    ```

    > This script finds the interface that is not `lo` or `docker` and attempts
    > to find an IP from it. This may require some tuning on your part depending
    > on assumptions you can make about your VMs.

1. Make the script executable.

    ```sh
    chmod +x /usr/local/bin/init-hostname
    ```

1. Create a systemd unit file at `/etc/systemd/system/init-hostname.service`.

    ```toml
    [Unit]
    Description=Set a hostname based on IP.
    ConditionPathExists=!/etc/hostname
    Wants=network-online.target
    After=network-online.target

    [Service]
    ExecStart=/usr/local/bin/init-hostname

    [Install]
    WantedBy=multi-user.target
    ```

1. Reload systemd and enable the service (on startup).

    ```sh
    systemctl daemon-reload && \
    systemctl enable init-hostname
    ```

## Cleaning Up the Image

As final steps, we need to ensure the hosts machine-id is removed such that it
asks for a new IP, the hostname is removed so that `init-hostname` sets it on
boot, and the swap partition is removed.

1. Remove the swap partition from `/etc/fstab`.

    ```diff
    # /etc/fstab: static file system information.
    #
    # Use 'blkid' to print the universally unique identifier for a
    # device; this may be used with UUID= as a more robust way to name devices
    # that works even if disks are added and removed. See fstab(5).
    #
    # <file system> <mount point>   <type>  <options>       <dump>  <pass>
    # / was on /dev/vda2 during curtin installation
    /dev/disk/by-uuid/764a9530-be34-427b-b28c-4ef2b4f43a0b / ext4 defaults 0 1
    # /boot/efi was on /dev/vda1 during curtin installation
    /dev/disk/by-uuid/0347-EBE1 /boot/efi vfat defaults 0 1
    - /swap.img       none    swap    sw      0       0
    ```

1. Remove the [machine-id](https://man7.org/linux/man-pages/man5/machine-id.5.html).

    ```sh
    echo -n > /etc/machine-id
    ```

1. Remove the hostname.

    ```sh
    rm -v /etc/hostname 
    ```

1. Shutdown the machine.

    ```sh
    poweroff
    ```

1. Copy the base image to your preferred location.

    ```sh
    cp -v /var/lib/libvirt/images/k8s-base.qcow2 \
        /var/lib/libvirt/bases/k8s-1.28-base.qcow2
    ```

    > /var/lib/libvirt/bases is a diretory I created on my hypervisor.

## Additional Tips

* Stop and remove a VM.

    ```sh
    #!/bin/sh
    NAME=k8s-base
    virsh destroy ${NAME}
    virsh undefine --nvram ${NAME}
    rm -v /var/lib/libvirt/images/${NAME}.qcow2
    ```
