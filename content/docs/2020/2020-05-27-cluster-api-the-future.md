---
title: Cluster API ... The Future?
weight: 9984
description: Exploring Cluster API for lifecycle management of Kubernetes clusters.
date: 2020-05-24
images:
- https://octetz.s3.us-east-2.amazonaws.com/cluster-api-the-future/title-card.png
aliases:
  - /latest
---

# Cluster API … The Future?

Kubernetes [cluster] lifecycle management. A topic that feels like we've spent
an eternity discussing. I don't mean that in a negative way, more so that I've
watched this space change slowly over time, as you'd expect. I remember the days
where most of us read [Kubernetes the Hard
Way](https://github.com/kelseyhightower/kubernetes-the-hard-way/tree/1.7.4) and
build automation around it. No joke, you'd be surprised how many shops I've
landed in to harden their deployments, only to find out their ansible was more
or less doing the same. Over time we've seen a drastic shift from this model all
the way down to managed services (EKS, AKS, GKE). Still, there remains a gap.
Questions like "How can I create an API-driven management system independent of
providers?" or "How can I manage the lifecycle in my on-prem deployment?". Hell
even some of us using managed services may desire a better way to operator our
worker nodes.

{{< cimg
src="https://octetz.s3.us-east-2.amazonaws.com/cluster-api-the-future/title-card.png"
width="800" >}}

The Cluster API project has been in the works for some time now. Its goal is
to bring consistent, API-driven, lifecycle management of Kubernetes clusters.
This is an exciting space as managing the lifecycle of clusters has been a
notoriously challenging task. Not to mention there's insane variance in how we
boostrap clusters, causing many of us to re-create the wheel time and time
again. In this post I'm going to provide perspective and an introduction around
Cluster API. This is **not a how to use Cluster API post**, that is already covered
[here](ihttps://cluster-api.sigs.k8s.io).

## How We Got Here

Back in 2016 at [CoreOS](http://coreos.com), I worked with several shops to help
them stand-up their Kubernetes clusters. In these early days many clusters were
science experiments more than anything. Nonetheless, the problems we had to
solve persisted, namely:

* **Infrastructure Provisioning**: Creating the network, compute, and storage
Kubernetes would eventually run on. Tools like Terraform would be used to
abstract the underlying provide APIs.

* **Image Baking**: Creating a suitable base OS. Probably some flavor of
RHEL/Centos/Ubuntu with a bunch of junk in it.

* **Configuration Management**: Configuring hosts with certificates, system
components, and connected them together. Tools like Ansible or Chef are often
used to download components and ensure a system capable of process management
was configured to run Kubernetes control plane services.

Commonly, a provisioning stack would be built, and it would look similar to:

{{< cimg
src="https://octetz.s3.us-east-2.amazonaws.com/cluster-api-the-future/provisioning-stack.png"
width="800" >}}

> Ommiting image baking concerns from this diagram.

As Kubernetes interest increased, this lead us into the era of **installers**.
Everyone and their cousin were writing installers. However, a few came out on
top.

{{< cimg
src="https://octetz.s3.us-east-2.amazonaws.com/cluster-api-the-future/installers.png"
width="800" >}}

I didn't have much luck with installers. Perhaps it was just my client's
"enterprise-y" needs, but typically they fell apart or fell over leaving us
having to maintain forks or customize them to a degree we would have been
better off just writing our own automation. Frankly, many of them bit off more
than they could chew in this bleeding edge ecosystem. We needed something that
was more closely aligned with the UNIX Philosophy. Enterprises had established
tools with teams built around them (see Ansible, Chef, etc). Largely, the
"newness here" was bootstrapping Kubernetes. What we really needed was a tool
that exclusively handled the Kubernetes bits and did not concern itself with
the ecosystem around it. With this, queue in our friend Kubeadm.

{{< cimg
src="https://octetz.s3.us-east-2.amazonaws.com/cluster-api-the-future/kubeadm.png"
width="150" >}}

For me, `kubeadm` hit the spot. It is a single binary that handled the key
bootstrapping concerns those new to Kubernetes were not looking to solve. This
meant I could walk into most enterprise environments, pull out my
statically-linked friend (kubeadm) and plug into their existing systems. Sure,
it wasn't an installer the tried to worry about my infrastructure, but that's
what I love about it. It instead focused on:

* Kubernetes host checks
* Certificate creation
* Control plane instantiation
* Joining nodes (via an ephemeral token system)

I built my fair share of clusters provisioning around this tool. Essentially in a
structure looking like:

{{< cimg
src="https://octetz.s3.us-east-2.amazonaws.com/cluster-api-the-future/provisioning-stack-v2.png"
width="1000" >}}

As seen above, `kubeadm` has largely replaced all the bits under configuration
management. You'll also notice the addition of the API and Pipeline boxes. As
Kubernetes adoption increased and patterns such as "clusters-as-cattle"
popularized, the frequency in which we'd create and destroy clusters did the
same. Building these fully automated, self-serve, systems where you got a
Kubernetes cluster with a click turned out to be a large feat for many
engineering groups. The maintenance overhead of all the components can become
daunting and quickly created a need for another approach.

It would be fair to think, "just bring back the installer!". But these
installers largely **still** don't cut it for many of these use cases.
Additionally, and installer won't necessarily fix our multi-cluster management
problem. If installers aren't giving us the experience desired, let's take a
step back and ask:

_What aspects of Kubernetes make it such a compelling workload orchestror?_ 

There are many, but a few key ones are:

* **Declarative API**

* **Desirable Client Tooling**
    * `kubectl` and surrounding ecosystem

* **Custom API Support (CRDs)**

* **Pluggable Controller Models**
    * e.g. ability to deploy an ingress controller based on your desired
    technology (nginx, envoy, etc)

What if we could take the above, proven model, and apply it to how we create,
manage, and destroy Kubernetes clusters? Could we get to a point where `kubectl
deploy -f cluster.yaml` could make a cluster appear? Yes...we can, it's Cluster API:

{{< cimg
src="https://octetz.s3.us-east-2.amazonaws.com/cluster-api-the-future/capi-parts.png"
width="600" >}}

With some history called out, I'll be diving into what cluster API is an how it
works to better determine if this is the future of Kubernetes bootstrapping.

## How it Works

As the logo implies, Cluster API uses Kubernetes to manage Kubernetes. You
end up with a **Management Cluster** that manages one or many **Workload
Clusters**. A workload cluster will appear as an ordinary Kubernetes cluster you
can build and run applications on. The management cluster runs special
workloads, so we'll start there.

A management cluster starts off as any other cluster. It can be one you've
created with [kind](https://kind.sigs.k8s.io) or, especially in non-test
cases, a cluster you've established in your infrastructure. To make this
cluster a management cluster, you initialize it with `clusterctl init
--provider=${PROVIDER}`. Where `${PROVIDER}` can be AWS, vSphere, etc. I won't
go through the step-by-step process to setup a management cluster as it's
already well documented in [the quickstart
guide](https://cluster-api.sigs.k8s.io/user/quick-start.html). Let's assume
you've gone through those steps and are initializing the cluster for AWS and
vSphere.

```
clusterctl init --provider=aws &&\
clusterctl init --provider=vsphere
```

> By default, this will run using your kubeconfig, and turn whatever cluster
  that it points to into a management cluster.

With the above run, you now have a **management cluster!** But...what does that
mean!? Well, specially you have:

* **Installed CRDs**:
  * CAPI (`Machine`, `Cluster`, etc)
  * ControlPlane (`KubeadmControlPlane`)
  * Bootstrap (`KubeadmConfig`, `KubeadmTemplate`)
  * Infrastructure (`AWSCluster`, `AWSMachine`, etc)

* **Deployed Controllers**:
  * Cluster Controller
  * Control Plane Controller 
  * Kubeadm Bootsrap Controller 
  * AWS Infrastructure Controller
  * vSphere Infrastructure Controller

In essence, the above components enable the eventual creation of `Machine`
objects. This is similar to how Kubernetes has multiple ways of creating a `Pod`,
be it through a `StatefulSet` or `Deployment`. In fact, the `MachineDeployment`
maps nearly 1:1 with what you're used to in a Kubernetes `Deployment`.

{{< cimg
src="https://octetz.s3.us-east-2.amazonaws.com/cluster-api-the-future/machinedeployment.png"
width="1000" >}}

The above machines represent what you'd conventionally refer to as worker nodes.
They can be scaled up, down, and deleted as you'd expect. A cluster can own
multiple `MachineDeployment`s, enabling you to have diverse pools of compute.
Control plane nodes are represented as `Machine` objects as well, but since the
control plane nodes have special operational concerns, it's managed via
`
KubeadmControlPlane`.
{{< cimg
src="https://octetz.s3.us-east-2.amazonaws.com/cluster-api-the-future/kubeam-cp.png"
width="375" >}}

Now you may be wondering, where do these machines get their configuration? This
is where a bootstrap provider comes in to play.
