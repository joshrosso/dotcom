---
title: 'Nix: Hypervisor, Kubernetes, and Containers'
weight: 9100
description: This guide accompanies my 2023 Kubecon talk, Nix, Kubernetes, and the Pursuit of Reproducibility. It demonstrates how to use Nix(OS) for all layers of a server stack. The hypervisor, which includes network stack configuration along with libvirt, qemu, and kvm. The VM stack, which includes the bits to run Kubernetes. And lastly, container images, which run on the Kubernetes cluster.
date: 2023-11-11
aliases:
---

# Nix: Hypervisor, Kubernetes, and Containters

[Nix](https://nixos.org), the language, packages, and operating system, is
seeing increased popularity with its promise of providing a highly-composable
way to create reproducible software. I've been intrigued by the Nix ecosystem
for some time as I often struggle to reproduce the exact configuration found on
my VMs and, at times, hypervisors. The reasoning for this struggle varies, but
often it's simply laziness of ensuring changes I've made on a host make it into
automation like Packer or Ansible. Trying to build my environment with Nix
seemed like a good way to rid myself of th is bad habit, while also learning a
new stack.

This guide will demonstrate the various configuration I've made in making this
transition to Nix(OS). I'll attempt to keep this guide pretty concise to the actual
steps taken, but see my Kubecon presentation for additional context (and some
jokes) around the use case:

{{< youtube TODO >}}

## Hypervisor

My hypervisors are run on an amalgamation of computers. These computers range
from decommissioned enterprise gear to old consumer hardware (often utilizing a
laptop or 2). For evidence of the "jankyness", see below:

<img src="https://files.joshrosso.com/img/site/nix-k8s/homelab.jpeg" height="400px">

Given that hardware may come and go, it's important I can provision the
hypervisor consistently. For setting up a hypervisor, the exercise largely
entails configuring networking and qemu/libvirt. Of course, this all comes after
the base-OS installation.

### OS Install via ISO

Since the hypervisor is installed on baremetal, we need to start by installing
the base NixOS operating system. Then we'll bring the custom configuration in.
I'll leave creating install media and installing the base OS to you. The Nix
community also has this [documented in their
manuals](https://nixos.org/manual/nixos/stable/#ch-installation).

One convenience I've created is a filesystem provisioning script and a base
install script. These scripts can be run from a remote machine. When you boot
your machine from the ISO, `sshd` will already be enabled. To utilize ssh, run
`passwd` and set a password for `root`, then you can SSH in from any remote
machines. The shell scripts I run from the remote machines look as follows.

```sh
#!/bin/sh

# inspired by https://github.com/mitchellh/nixos-config/blob/0547ecb427797c3fb4919cef692f1580398b99ec/Makefile#L51-L77
ssh root@${NIXADDR} " \
    umount -R /mnt; \
    wipefs -a /dev/sda; \
    parted -s /dev/sda -- mklabel gpt; \
    parted /dev/sda -- mkpart primary 512MiB 100\%; \
    parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB; \
    parted /dev/sda -- set 2 esp on; \
    sleep 1; \
    mkfs.ext4 -L nixos /dev/sda1; \
    mkfs.fat -F 32 -n boot /dev/sda2; \
    sleep 1; \
    mount /dev/disk/by-label/nixos /mnt; \
    mkdir -p /mnt/boot; \
    mount /dev/disk/by-label/boot /mnt/boot; \
"
```

The above sets up system partitions and uses any remaining space for root. For
simplicity I've left volume encryption out of this guide, however you may want to
consider setting this up. The next script performs the base install:

```sh
#!/bin/sh

ssh root@${NIXADDR} " \
    nixos-generate-config --root /mnt; \
    sed --in-place '/system\.stateVersion = .*/a \
      nix.extraOptions = \"experimental-features = nix-command flakes\";\n \
      services.openssh.enable = true;\n \
      services.openssh.passwordAuthentication = true;\n \
      services.openssh.permitRootLogin = \"yes\";\n \
      users.users.root.initialPassword = \"root\";\n \
    ' /mnt/etc/nixos/configuration.nix; \
    nixos-install --no-root-passwd; \
 "
```

Assuming the above scripts are called `setup-filesystem.sh` and
`install-nix.sh` respectively, I can install against the hypervisor by running
the following from a remote client.


```sh
NIXADDR=192.168.33.23 ./setup-filesystem.sh
NIXADDR=192.168.33.23 ./install-nix.sh
```

Now we have NixOS installed and layed out on a simple partition scheme. From
here we can reboot and start configuring the system.

### Networking and Software

For my hypervisors, the networking configuration involves a bridge interface
that acts a virtual switch for the VMs. The bridge interface is connected to a
physical nic's interface. In this model, VMs get a routable (LAN) IP address
from DHCP. For details on hypervisor networking, you may find my post [VM
Networking](https://joshrosso.com/c/vm-networks) interesting. Visually, you can
think of the networking setup as follows:

<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.1" width="100%" viewBox="-0.5 -0.5 831 381" content="&lt;mxfile host=&quot;Electron&quot; modified=&quot;2023-11-12T15:14:23.640Z&quot; agent=&quot;Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) draw.io/21.2.8 Chrome/116.0.5845.228 Electron/26.3.0 Safari/537.36&quot; etag=&quot;RJzxkWrmx47lUwb6EJPX&quot; version=&quot;21.2.8&quot; type=&quot;device&quot;&gt;&lt;diagram name=&quot;Page-1&quot; id=&quot;Pce8RPPKagThAF2YylDD&quot;&gt;1Vlbb9owGP01SNvDqthOCDwW2o5Jq9aJh61PlUncxFuIkWMu2a+fTWwSN+FSAQ1ICOLP1xyfc3yhg4bT1VeOZ/EjC0nSgU646qC7DoTARa78UZFcRxzHKSIRp6GOlYEx/UdMQR2d05BkVkHBWCLozA4GLE1JIKwY5pwt7WKvLLF7neGI1ALjACf16C8airiI9jynjI8IjWLTMzDvN8WmsA5kMQ7ZshJC9x005IyJ4mm6GpJEoWdwKeo9bMndDIyTVBxSYTSYDygeD90J8B5efoweZz9fvuhWFjiZ6xfuwG4i2xtM5EOkHuJ8RviCZoybLNnHJldW7qBb9YGObiwTuUGPs3kaEjUAWWqwjKkg4xkOVO5SEka1LqaJTAH5uCBcUIn8bUKjVMYEm607WA9Q5pHV1jcHGzwlEwmbEsFzWURXgGZONAkh0ullOaN+X8fiymwiM81YsyjatF0CLR801u/A3a1BRULJO51kXMQsYilO7svowAazLPOdKaDWEP4hQuRaRHgumA1w0afqaDeQclxszgOyY/xQSxHziIgd5VDzxHCSYEEX9jhODjLcT26aCsJfFSP3cJuI2KnN2bvofQoiI3jjWVT2nDqVAWigsnsuJqMayCkRS8b/qooluk6Aedg+gOANfN0G+FyvDh88F3zdNoxAosXz36q+pJNOPuvm1om7lZXKdeqEBuIdaCCwTQPx9hvIRO5aImJzfbeTTHj7RoKQrQMX1nXggQYdnM1G/P1QLygXc5ys91ZBTNO9SF/sfgS+2Y/4dfRl8KYB/423n3wC+le+I+kdaChem4bSO+WOJM1Q+0bi2VRGDQtqv/eB66nRx0mNBF6okbg9cHlGYpaNq3USYO4ZLtpKwAFH9+vyki6w2dy+lxxwgHy3lxyJ89m8xHcvcFMC2jkeraionI5k6rmSU56NVMIcjS7gSAXQVfhW/cLgyn2r51/aHqjXimqMAoDF/1IOWxRA0vBWXdTLZMpSUkQeqHrldX6Is3g9rlMv8/5VyGX7wZgaReBAZEXf8kuV3axJ2ZKKIK6oiJYqOkY1DXNynIRc/5CLTdhwsdk9l4pg/ZrmI9eeysrj3PhmIWpefKzp2KenU0qof6CEwLHXeOuq8rVwXikwY3KhyCotP6lAhVWea29p9M1uyYqixZIjm6EdIdj+fsESrETpLKaKyxvZSu4IPEnUZeK3J/n1aUFV+G40fPp8+RLugzf7xzMKWCbL/02LiSv/fkb3/wE=&lt;/diagram&gt;&lt;/mxfile&gt;" style="background-color: rgb(255, 255, 255);"><defs/><g><rect x="0" y="30" width="790" height="350" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"/><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe flex-start; justify-content: unsafe center; width: 788px; height: 1px; padding-top: 37px; margin-left: 1px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="box-sizing: border-box; font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: Helvetica; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><b>hypervisor</b> :: 1</div></div></div></foreignObject><text x="395" y="49" fill="rgb(0, 0, 0)" font-family="Helvetica" font-size="12px" text-anchor="middle">hypervisor :: 1</text></switch></g><path d="M 87.5 340 L 87.5 360 L 87.5 340 L 87.5 353.63" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"/><path d="M 87.5 358.88 L 84 351.88 L 87.5 353.63 L 91 351.88 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"/><rect x="32.5" y="300" width="110" height="40" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"/><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 108px; height: 1px; padding-top: 320px; margin-left: 34px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="box-sizing: border-box; font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: Helvetica; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><b>interface</b> :: eth0</div></div></div></foreignObject><text x="88" y="324" fill="rgb(0, 0, 0)" font-family="Helvetica" font-size="12px" text-anchor="middle">interface :: eth0</text></switch></g><rect x="15" y="360" width="145" height="20" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"/><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 143px; height: 1px; padding-top: 370px; margin-left: 16px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="box-sizing: border-box; font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: Helvetica; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;">network interface card</div></div></div></foreignObject><text x="88" y="374" fill="rgb(0, 0, 0)" font-family="Helvetica" font-size="12px" text-anchor="middle">network interface card</text></switch></g><path d="M 392.5 260 L 392.5 280 L 87.5 280 L 87.5 293.63" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"/><path d="M 87.5 298.88 L 84 291.88 L 87.5 293.63 L 91 291.88 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"/><rect x="135" y="220" width="515" height="40" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"/><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 513px; height: 1px; padding-top: 240px; margin-left: 136px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="box-sizing: border-box; font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: Helvetica; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><b>bridge interface</b> :: br0</div></div></div></foreignObject><text x="393" y="244" fill="rgb(0, 0, 0)" font-family="Helvetica" font-size="12px" text-anchor="middle">bridge interface :: br0</text></switch></g><rect x="20" y="70" width="227.5" height="110" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"/><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe flex-start; justify-content: unsafe center; width: 226px; height: 1px; padding-top: 77px; margin-left: 21px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="box-sizing: border-box; font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: Helvetica; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><b>virtual machine</b> :: 1</div></div></div></foreignObject><text x="134" y="89" fill="rgb(0, 0, 0)" font-family="Helvetica" font-size="12px" text-anchor="middle">virtual machine :: 1</text></switch></g><path d="M 199 180 L 199 200 L 392.5 200 L 392.5 213.63" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"/><path d="M 392.5 218.88 L 389 211.88 L 392.5 213.63 L 396 211.88 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"/><rect x="150" y="160" width="98" height="20" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"/><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 96px; height: 1px; padding-top: 170px; margin-left: 151px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="box-sizing: border-box; font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: Helvetica; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><b>interface</b> :: ens3</div></div></div></foreignObject><text x="199" y="174" fill="rgb(0, 0, 0)" font-family="Helvetica" font-size="12px" text-anchor="middle">interface :: ens3</text></switch></g><rect x="281" y="70" width="227.5" height="110" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"/><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe flex-start; justify-content: unsafe center; width: 226px; height: 1px; padding-top: 77px; margin-left: 282px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="box-sizing: border-box; font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: Helvetica; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><b>virtual machine</b> :: 2</div></div></div></foreignObject><text x="395" y="89" fill="rgb(0, 0, 0)" font-family="Helvetica" font-size="12px" text-anchor="middle">virtual machine :: 2</text></switch></g><path d="M 460 180 L 460 200 L 392.5 200 L 392.5 213.63" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"/><path d="M 392.5 218.88 L 389 211.88 L 392.5 213.63 L 396 211.88 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"/><rect x="411" y="160" width="98" height="20" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"/><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 96px; height: 1px; padding-top: 170px; margin-left: 412px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="box-sizing: border-box; font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: Helvetica; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><b>interface</b> :: ens3</div></div></div></foreignObject><text x="460" y="174" fill="rgb(0, 0, 0)" font-family="Helvetica" font-size="12px" text-anchor="middle">interface :: ens3</text></switch></g><rect x="540" y="70" width="227.5" height="110" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"/><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe flex-start; justify-content: unsafe center; width: 226px; height: 1px; padding-top: 77px; margin-left: 541px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="box-sizing: border-box; font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: Helvetica; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><b>virtual machine</b> :: 3</div></div></div></foreignObject><text x="654" y="89" fill="rgb(0, 0, 0)" font-family="Helvetica" font-size="12px" text-anchor="middle">virtual machine :: 3</text></switch></g><path d="M 719 180 L 719 200 L 392.5 200 L 392.5 213.63" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="stroke"/><path d="M 392.5 218.88 L 389 211.88 L 392.5 213.63 L 396 211.88 Z" fill="rgb(0, 0, 0)" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" pointer-events="all"/><rect x="670" y="160" width="98" height="20" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" pointer-events="all"/><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 96px; height: 1px; padding-top: 170px; margin-left: 671px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="box-sizing: border-box; font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: Helvetica; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><b>interface</b> :: ens3</div></div></div></foreignObject><text x="719" y="174" fill="rgb(0, 0, 0)" font-family="Helvetica" font-size="12px" text-anchor="middle">interface :: ens3</text></switch></g><path d="M 707.5 300 L 707.5 240 L 650 240" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" stroke-dasharray="3 3" pointer-events="stroke"/><rect x="647.5" y="300" width="120" height="60" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" stroke-dasharray="3 3" pointer-events="all"/><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 118px; height: 1px; padding-top: 330px; margin-left: 649px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="box-sizing: border-box; font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: Helvetica; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><i>acts as a virtual switch</i></div></div></div></foreignObject><text x="708" y="334" fill="rgb(0, 0, 0)" font-family="Helvetica" font-size="12px" text-anchor="middle">acts as a virtual sw...</text></switch></g><path d="M 710 45 L 654 45 L 654 70" fill="none" stroke="rgb(0, 0, 0)" stroke-miterlimit="10" stroke-dasharray="3 3" pointer-events="stroke"/><rect x="710" y="0" width="120" height="60" fill="rgb(255, 255, 255)" stroke="rgb(0, 0, 0)" stroke-dasharray="3 3" pointer-events="all"/><g transform="translate(-0.5 -0.5)"><switch><foreignObject pointer-events="none" width="100%" height="100%" requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility" style="overflow: visible; text-align: left;"><div xmlns="http://www.w3.org/1999/xhtml" style="display: flex; align-items: unsafe center; justify-content: unsafe center; width: 118px; height: 1px; padding-top: 30px; margin-left: 711px;"><div data-drawio-colors="color: rgb(0, 0, 0); " style="box-sizing: border-box; font-size: 0px; text-align: center;"><div style="display: inline-block; font-size: 12px; font-family: Helvetica; color: rgb(0, 0, 0); line-height: 1.2; pointer-events: all; white-space: normal; overflow-wrap: normal;"><i>each vm has a routable IP (via DHCP)</i></div></div></div></foreignObject><text x="770" y="34" fill="rgb(0, 0, 0)" font-family="Helvetica" font-size="12px" text-anchor="middle">each vm has a routab...</text></switch></g></g><switch><g requiredFeatures="http://www.w3.org/TR/SVG11/feature#Extensibility"/><a transform="translate(0,-5)" xlink:href="https://www.drawio.com/doc/faq/svg-export-text-problems" target="_blank"><text text-anchor="middle" font-size="10px" x="50%" y="100%">Text is not SVG - cannot display</text></a></switch></svg>

After installing the base system, a file named `/etc/nixos/configuration.nix`
was created. This is the file to update with networking and software details. I
like to keep this file as is, but add an extra one to `/etc/nixos/extra.nix`. I
went ahead and added a `# TODO(you)` comment to each area you're likely to need
to update.

```nix
{ config, pkgs, ... }:

{
  # TODO(you): switch this for kvm-amd if using AMD instead.
  boot.kernelModules = [ "kvm-intel" ];

  # disable dhcpcd since we'll use systemd-networkd
  networking.useDHCP = lib.mkDefault false;

  systemd.network = {
    enable = true;
    netdevs = {
       # Create the bridge interface
       "20-br0" = {
         netdevConfig = {
           Kind = "bridge";
           Name = "br0";
         };
       };
    };
    networks = {
      # TODO(you): update `30-enp2s0` to your NIC's interface (run `ifconfig`)
      # Connect the bridge ports to the bridge
      "30-enp2s0" = {
        # TODO(you): update `enp2s0` to your NIC's interface (run `ifconfig`)
        matchConfig.Name = "enp2s0";
        networkConfig.Bridge = "br0";
        linkConfig.RequiredForOnline = "enslaved";
      };
      "40-br0-dhcp" = {
    	matchConfig.Name = "br0";
	networkConfig = {
	  DHCP = "ipv4";
	};
      };
    };
  };

  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.allowedBridges = [
	"br0"
  ];
  # required by libvirtd
  security.polkit.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    wget
    jq
    curl
    virt-manager
    htop
    prometheus
    prometheus-node-exporter
    prometheus-process-exporter
  ];

  environment.variables.EDITOR = "nvim";

  # Enable the OpenSSH daemon.
  services.tailscale.enable = true;
  services.openssh.enable = true;
  services.openssh.passwordAuthentication = true;
  services.openssh.permitRootLogin = "yes";
  services.openssh.extraConfig = ''
AllowStreamLocalForwarding yes
AllowTcpForwarding yes
  '';

  # note this setting, in cause you wish to be more restrictive at the OS-level.
  networking.firewall.enable = false;

}
```

Reading the configuration above tells most of the story, but lets call out a few things.

1. We are setting `dhcpcd` to false in favor of using `systemd-networkd`. Otherwise
   [it would be defaulted to
   true](https://search.nixos.org/options?channel=23.05&show=networking.dhcpcd.enable&from=0&size=50&sort=relevance&type=packages&query=networking.dhcp).
1. Enabling `virualization.libvirt` handles much of the plumbing and ensures
   associated packages are installed.
1. If your networking does not work on boot, use `journalctl -u systemd-networkd` to view the logs.
1. Nix performs a hardware scan, which imports the majority of required
   hardware-specific configuration, however we do enable KVM above (change this
   setting if using AMD).

To use the `extra.nix` file in our system build, we need to import it to `/etc/nixos/configuration`.

```nix
{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./extra.nix
    ];
```

Now we're set to re-build the operating system. Normally these changes can
happen in place, but since we're configuring network interfaces, I recommend a
full reboot.

```sh
nixos-rebuild switch
```

## VM

Now lets create VM images capable of running Kubernetes. There are a variety of
ways to approach this, one of which is to use [the Kubernetes modules provided
by
NixOS](https://search.nixos.org/options?channel=23.05&from=0&size=50&sort=relevance&type=packages&query=kubernetes).
However, in my lab, I prefer setting up the base packages, unit files, and then
leveraging `kubeadm` to manage the Kubernetes bits. Admittedly, mutating the
system with `kubeadm` is a little impure as far as Nix is concerned, but I'm ok
with that. So, for the VMs, the following things are going to be setup.

1. `kubeadm`.
1. Kubernetes bits (e.g. `kubelet`, `kubectl`).
1. A container runtime (`containerd`).

These have some dependencies we need to consider as well, but for now, let's
examine a `configuration.nix` file that may encompass the above.

```nix
{ config, pkgs, ... }:

{

  # text that shows up when you ssh in. Makes for an easy parameter to change
  when testing builds too.
  users.motd = "Hello Kubecon Chicago!!!";

  networking.hostName = "";
  system.stateVersion = "23.05";

  virtualisation.containerd = {
        enable = true;
        configFile = ./containerd-config.toml;
  };


  # kernel modules and settings required by Kubernetes
  boot.kernelModules = [ "overlay" "br_netfilter" ];
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward" = 1;
  };


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    neovim
    wget
    ripgrep
    prometheus-node-exporter
    prometheus-process-exporter
    kubernetes
    containerd
    cri-tools

    ebtables
    ethtool
    socat
    iptables
    conntrack-tools
    (import ./hostname.nix)
  ];


  systemd.services.kubelet = {
    enable = true;
    description = "kubelet";
    serviceConfig = {
      ExecStart = "${pkgs.kubernetes}/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS";
      Environment = [
        "\"KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf\""
        "\"KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml\""
        "PATH=/run/wrappers/bin:/root/.nix-profile/bin:/etc/profiles/per-user/root/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
      ];
      EnvironmentFile = [
        "-/var/lib/kubelet/kubeadm-flags.env"
        "-/etc/default/kubelet"
      ];
      Restart = "always";
      StartLimitInterval = 0;
      RestartSec = 10;
    };
    wantedBy = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  systemd.services.hostname-init = {
    enable = true;
    description = "set the hostname to the IP";
    serviceConfig = {
      ExecStart = "/run/current-system/sw/bin/hostname-init";
    };
    wantedBy = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  environment.variables.EDITOR = "nvim";

  # Enable the OpenSSH daemon.
  users.users.root.initialPassword = "root";
  services.openssh.enable = true;
  services.openssh.passwordAuthentication = true;
  services.openssh.permitRootLogin = "yes";
  networking.firewall.enable = false;

}
```

The above references some external files we'll examine now. The first is the
`containerd-config.toml`. This is needed as there is some specific
configuration required [per the Kubernetes
docs, namely the cgroup driver](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#cgroup-drivers).
The config file is really long, so in this guide I'll show pulling from a link:

```sh
wget https://raw.githubusercontent.com/joshrosso/hypernix/main/vm-images/containerd-config.toml
```

The last extra config is `hostname.nix`. This is...less than ideal...but works
really well for me until I have a more capable DHCP setup. The idea is that
when a host boots the unit file resolves the DHCP-provided IP address and
generates a hostname. It then reboots the system and continues forward. This
approach (hack?) assumes the IP address will never change for the life of the
VM. The `nix` definition is:

```nix
with import <nixpkgs> {};

writeShellApplication {

	name = "hostname-init";

	text = ''
	#!/bin/sh
	SN="hostname-init"

	# do nothing if /etc/hostname exists
	if [ -f "/etc/hostname" ]; then
		  echo "''${SN}: /etc/hostname exists; noop"
		    exit
	fi

	SN="hostname-init"

	echo "''${SN}: creating hostname"

	# set hostname
	/run/current-system/sw/bin/ip -o -4 addr show | /run/current-system/sw/bin/awk '!/ lo | docker[0-9]* /{ sub(/\/.*/, "", $4); gsub(/\./, "-", $4); print $4 }' > /etc/hostname

	if [ -f "/etc/hostname" ]; then
          /run/current-system/sw/bin/reboot
	fi
	'';
}
```

If you use the above and it gives you problems, use `journalctl -u hostname-init` to see the logs.

The above expresses a base configuration that could be used in a variety of
image formats. Since our hypervisor stack is built on KVM/qemu/libvirt, we'll
plan to use `qcow2` as the format. The
[nixos-generators](https://github.com/nix-community/nixos-generators) project
is where I went to get details on how to build for a variety of outputs. I've
since translated some things into [this
repo](https://github.com/joshrosso/hypernix/tree/main/vm-images), which if
cloned down, you can fun the following command:

```sh
nix-build ./nixos-generate.nix \
    --argstr formatConfig /root/hypernix/vm-images/formats/qcow.nix \
    -I nixos-config=configuration.nix \
    --no-out-link \
    -A config.system.build.qcow
```

However, rather than using mine, you may wish to see if you can get the
`nixos-generators` project to work since it's actually maintained. Once the
above command builds, you'll see an output in the `/nix/store`, as seen below.

```sh
[root@nixos:~/hypernix/vm-images] ls /nix/store/aa494ixhf52l295c7isdkylvr135j84q-nixos-disk-image
nixos.qcow2
```

I tend to move these base images into
`/var/lib/libvirt/images/{SOME_DIRECTORY}`. Although the exact location is
entirely up to you.

With the base image in place, it's a matter of standing up virtual machines. I
control this through Terraform, but that's a bit too long for this exercise.
Instead, here's a script that will spawn 3 VMs based on the image generated
above.

```sh
# TODO(you): change this to where you move your image to.
PATH_IMG=/var/lib/libvirt/images/
NAME=k8s_base

for i in {1..3}
do
	cp -v ${PATH_IMG}/${NAME}.qcow2 ${PATH_IMG}/${NAME}-${i}.qcow2
	virt-install \
	  --name kubecon_$i \
	  --ram 6000 \
	  --vcpus 2 \
	  --os-variant generic \
	  --console pty,target_type=serial \
	  --bridge=br0 \
	  --graphics=vnc,password=foobar,port=592${i},listen=0.0.0.0 \
	  --disk=${PATH_IMG}/${NAME}-${i}.qcow2 \
	  --import &
done
```

Once the VMs are up, determine their IPs, SSH into them, and run `kubeadm init`
and `kubeadm join` to create your multi-node cluster.


## Containers

Containers will be run in the cluster via a Pod. Nix can be used to create
OCI-compliant container images, which then run via a container runtime such as
`containerd`. As far as I know, `pkgs.dockerTools` is the most ubiquitous was
to produce images with Nix. It has a bunch of mapping that relate to what you'd
expect in a Dockerfile, and many more benefits such as the ability to ensure
each `/nix/store` asset built is put in its own layer. Don't like the
**docker** part of the tool name throw you off. The outputted image will be able
run with any container runtime that support OCI-based images (which should be
most/all of them).

Below is an example of an image building `nginx`, this is largely copied from
the [upstream
examples](https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/docker/examples.nix).
You can put the example in any directory and name it `nginx-container.nix`.

```nix
{ pkgs ? import <nixpkgs> { }
, pkgsLinux ? import <nixpkgs> { system = "x86_64-linux"; } }:

let
  conf = {
    nginxWebRoot = pkgs.writeTextDir "index.html"
      "  <html><body><center><marquee><h1>all ur PODZ is belong to ME</h1></marquee> <img src=\"https://m.media-amazon.com/images/M/MV5BYjBlODg3ZTgtN2ViNS00MDlmLWIyMTctZmQ2NWYwMzE2N2RmXkEyXkFqcGdeQVRoaXJkUGFydHlJbmdlc3Rpb25Xb3JrZmxvdw@@._V1_.jpg\" width=\"100%\"></center></body></html>\n";
    nginxPort = "80";
    nginxConf = pkgs.writeText "nginx.conf" ''
      user nobody nobody;
      daemon off;
      error_log /dev/stdout info;
      pid /dev/null;
      events {}
      http {
        access_log /dev/stdout;
        server {
          listen ${conf.nginxPort};
          index index.html;
          location / {
            root ${conf.nginxWebRoot};
          }
        }
      }
    '';
  };
in pkgs.dockerTools.buildLayeredImage {
  name = "joshrosso/kubecon";
  tag = "1.4";
  contents = [ pkgs.fakeNss pkgs.nginx ];

  extraCommands = ''
    mkdir -p tmp/nginx_client_body

    # nginx still tries to read this directory even if error_log
    # directive is specifying another file :/
    mkdir -p var/log/nginx
  '';
  config = {
    Cmd = [ "nginx" "-c" conf.nginxConf ];
    ExposedPorts = { "${conf.nginxPort}/tcp" = { }; };
  };
}
```

With the above declared, we can run `nix-build` and create an image.

```sh
nix-build nginx-container.nix
```

This will create a multi-layer image and create a symlink named `result`. You
can now load the tarball into a container tool like `docker` and push it to a
remote repository.

```sh
docker load < result
docker push joshrosso/kubecon:1.4
```

In my Kubecon talk (video above) I validated the container's functionality by
deploying the pod, then port-forwarding to it and opening it in a web browser.

The manifest looked as follows:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: a-message-from-the-underworld
spec:
  containers:
  - name: message
    image: joshrosso/kubecon:1.4
    ports:
    - containerPort: 80
```

The port-forward command

```sh
kubectl port-forward --address 0.0.0.0 pods/a-message-from-the-underworld 8080:80
```

The app could then be opened in a web browser as seen below.

<img src="https://files.joshrosso.com/img/site/nix-k8s/hades-demo.png">

## Next Steps

There's a lot more to explore in the Nix ecosystem, but here are some specific
things you may wish to look into if you decided to build on what's in this
guide.

1. Add non-root users to your hypervisor and VMs.
1. Read [nix-pills](https://nixos.org/guides/nix-pills/) to better understand the language, packages, and OS.
1. Checkout farcaller's NixCon talk on [Kuberentes deployments with
   Nix](https://www.youtube.com/watch?v=SEA1Qm8K4gY), it covers using Nix for
   manifest generation.
1. Considering running NixOS on your desktop/laptop.
