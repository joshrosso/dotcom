---
title: Why and Why Not Kubernetes
weight: 9990
description: Explore the world of why you'd consider Kubernetes at your organization.
images:
- https://octetz.s3.us-east-2.amazonaws.com/title-card-why-k8s.png
aliases:
  - /latest
---

# Why and Why Not Kubernetes

So you've been hearing about this thing called Koobernuties. Neat! You proceed
to read articles about how it's the "ubiquitous cloud operating system" and a
bunch of other generalizations that hold about as much technical merit as a
Gartner Magic Quadrant report. It uses containers and you like those, also there
is some cute thing about [a giraffe and zebra going to the
zoo](https://www.cncf.io/phippy-goes-to-the-zoo-book/). Fast-forward to 2020.
You walk into work and overhear a conversation amongst your CIO and some
co-workers. They're discussing the rollout of Kubernetes. Excitedly someone says
"FINALLY something to solve agility.". Wait...wtf does it mean to solve agility?
As you dig deep into the interwebs (rather than getting work done) you discover
a few articles about how Kubernetes failed, how you don't need it, and how
Kubernetes kicked someone's dog one time. Hours later, that same CIO walks past
your desk with the "architect", proclaiming "...and by introducing a service
mesh we'll be able to solve observability and security!". You then proceed to
smash your face against your keyboard and take an [un-intended] nap.

There's a lot to navigate here and if you're feeling a little unsure, don't
worry! In this post I'm going to take an opinionated look at why or why not
Kubernetes. I've spent the last 4 years architecting and deploying Kubernetes in
multiple environments and i'll be building on those successes and failures to
provide perspective. That said, I'm going to try to minimize assumptions in a
way that will make this an interesting read for anyone new or "aged" to this
space. In the end, I hope you'll leave this with some increased perspective on
the value of Kubernetes and whether it's appropriate to introduce for your
needs.

## Evolution of Compute

It is important to start by recognizing the evolution of compute. Namely,
exploring servers, VMs, and containers. Don't expect this to be an exhaustive
representation of history. I've only included what I perceive as key points for
brevity.

### Servers

For now, you can ignore mainframes and start at the adoption "servers". With
limited concern for desktop environments and a different form factor, these
computers provided a location to run applications. Today, servers are often
referred to as "bare metal", which implies running applications directly on the
server rather than virtual servers (VMs).

{{< img src="https://octetz.s3.us-east-2.amazonaws.com/why-k8s-server.png"
class="center" width="600" >}}

As adoption of using servers to run applications increases, it raises some new
and interesting problems.

* How can you ensure the best usage of resources (CPU and memory)?
* What if applications require different environments? E.g. Operating Systems or
  libraries. Should you introduce a new server for each unique environment
  required?
* How can you isolate applications running on the same server?
    * Ensure applications don't impact each other on a resource level.
    * Ensure applications cannot breach one another.
* How can you ensure better consistency between environments? Developers won't
  always have a server under their desk.

### Virtual Machines (VMs)

To solve the above and many more problems, Virtual Machines (VMs) gained
popularity. They allowed you to run many "virtual servers" on one physical
server. As you may know, when you ask AWS, Azure, or Google Cloud for a server,
you're [usually] getting a VM. VMs run off a hypervisor, which is not important
to know for this post. The key is the ability to run many servers on one
physical server and that it was able to solve the list above.

{{< img src="https://octetz.s3.us-east-2.amazonaws.com/why-k8s-vms.png"
class="center" >}}


VMs have and still do get us very far in regards to running applications. With
automation you can declare the need for a VM in a DSL or code, execute it, and
poof you get a VM. However, VMs and more modern patterns for software have
created some noticeable complications.

* VMs [generally] contain an entire operating system, which will be replicated
  for every VM instance.
    * Some applications may only need some or none (e.g. statically-linked
      binaries) of the libraries on the host.
        * These unused libraries widen the attack surface.
* Applications are being composed of smaller "units" often referred to as
  [micro] services. This exasperates the point above as even more VMs must be
  created to run each service truly independently.
* How can you minimize the environment needed for a developer to test their
  application?
    * VMs can be multiple GBs in size.
    * Building a new VM can take time. 

### Containers

Containers can be thought of as processes running on a server (VM or otherwise)
with some clever isolation tricks to make them feel as if they're running on
their own server.  Before I mention Docker and someone runs in screaming "DOCKER
DIDN'T MAKE CONTAINERS NOOB", let's acknowledge that the primitives used to
create containers have been around for a long time. Two of the most important
and commonly cited are

* Namespaces - isolation of filesystem, network, and more.
* Cgroups - resource management CPU, memory, and more.

These are available in most modern Linux kernels. It is also worth mentioning
that many technologies have been around doing container-y things.

* Solaris Zones
* FreeBSD Jails

All this said, Docker was to containers as Rails was to Ruby. Docker brought a
user experience around packaging, running, and managing containers that
operators and developers could understand. By creating minimal images that felt
like VMs, developers were enabled to use something familiar but more optimal for
their development flow. Container images only need to include an application
runtime and the compiled code/bytecode. Additionally, Docker introduced
Dockerfiles that gave a declarative and reproducible way to build images for
applications. Today many alternatives to Docker are becoming popular (e.g. CRI-O
and Containerd). Each have their own trade-offs.


Containers have not put VMs out of a job. In-fact, most containers run on VMs
simply by the nature that many organizations run VMs and most cloud-provider
offerings are VM-based. I once had a potential customer tell me "Don't talk to
me about running containers on VMs, I don't want run a hypervisor on a
hypervisor". To which I responded, "OK, gl;hf" and walked out of the room.
Jokes aside, containers do enable interesting baremetal use-cases and I've been
lucky enough to do some baremetal deployments. But there are trade-offs you need
to consider, such as, how well does the container runtime handle 6000 containers
on 1 host with 1TB or RAM and 84 CPUs? Answer: not good. You can think of
containers and VMs as a ven diagram of problems solved and produced.


{{< img src="https://octetz.s3.us-east-2.amazonaws.com/why-k8s-containers.png"
class="center" >}}

Lastly, we must call out that Containers are no silverbullet. They've introduced
many issues themselves, including the following.

* Easy to setup insecurely.
* Lack of hypervisor isolation has made apps more prone to bad things when
  vulnerabilities arise, such as privilege escalation.
    * Hard to create a truly hardened multi-tenant environments with containers.

## Container Madness

{{< img src="https://octetz.s3.us-east-2.amazonaws.com/why-k8s-container-madness.png"
class="center" width="400" >}}

As time went on, containers began gaining steam. More developers were packaging
up their applications in containers, installing docker on servers and running
their workloads. People got the portability they wanted without the full bloat
of an OS. With a growing number of containers came a massive opportunity:

How can you orchestrate containers across multiple hosts?

Many solved this problem by introducing automation tools like Anisble. However,
it became extremely clear there was an opportunity for a tool that could
understand characteristics of the hosts it 'manages' and make informed decisions
about where and how to run containers. Many tried to solve for this issue
(shoutout fleet) but 3 primary options were pulling ahead of the others.

* Mesos
* Swarm
* Kubernetes (including OpenShift)

I won't waste your time in this post talking about the differences, but suffice
to say Kubernetes pulled ahead of these other projects for reasons such as:

* Easy to bootstrap and setup dev environments
* Declarative API
* Feature rich (namely, implemented the "right" features)
* Vendor-neutral 
* Thriving community

## Examining Kubernetes

With all this context, we can finally get to the important part, Kubernetes.

### What does Kubernetes solve?

This is likely the most confused area for humans new to Kubernetes. What does it
solve, exactly? Kubernetes has so many moving pieces and such a thriving
ecosystem extending it and building on top of it, it's hard to see where
Kubernetes starts and ends. Many organizations use a PaaS, which usually implies
a fully baked solution that takes your applications and runs them. It covers
your technical concerns end-to-end. Consider for a moment the following diagram
I'll call "pieces of a platform".

{{< img src="https://octetz.s3.us-east-2.amazonaws.com/platform-components.png"
class="center" width="400" >}}

The surprise to many is that Kubernetes primarily covers the green square above.

I [somewhat jokingly] tell people "Kubernetes just moves containers around
hosts". While overly simplified, it's not _that far_ from the conceptual truth.
What many ignore initially is the work involved in going from "we have a
Kubernetes" to "we have a hardened platform our apps can be successful atop".
Take 1 piece of the puzzle, authorization. Without proper PSP configuration and
custom admission control, anyone can pretty much take over a host and do bad
things.

{{< tweet 1129468485480751104 >}}

This doesn't mean that Kubernetes is inherently flawed. Authorization isn't a
core concern of Kubernetes. In fact, Kubernetes has geniously provided ways to
plug custom authorization approaches in such as Open Policy Agent to ensure you
can do authorization exactly how you need to. And authorization is just one
example, a few other things you'll need to figure out when making your
Kubernetes-based platform production ready.

* Container Networking
* Container Network Policy Enforcement (egress & ingress)
* Storage
* Resource constraints (limits and requests)
* Showback and chargeback
* Monitoring, Alerting, and Tracing
* Provider integration (vSphere, Openstack, AWS)
* Loadbalancing

Don't worry, the options to solve these problems are super straight forward.

{{< img src="https://octetz.s3.us-east-2.amazonaws.com/cncf-landscape.png"
class="center" >}}

Just kidding....and thus many groups or companies offer distributions or
platforms built on top of Kubernetes, such as OpenShift.

Speaking to the distributions, I'd argue they often only get you so far. They
might choose a container networking plugin and drop default monitoring in, but
productionalizing it is far more involved.

### Do I need Kubernetes?

The million dollar (sometimes quite literally) question. There’s not a clear
answer or decision tree that captures the nuances of every organization. Thus, I
can’t tell you (after all, I’m just some idiot on the internet) but let’s try to
explore it with some framing.

For me, there are three questions I think about about.

1. Who is your audience?
1. What problems are worth solving?
2. What are your capabilities and tolerance for risk?

Knowing your audience implies understanding the consumers of a Kubernetes-based
platform along with their cloud-native maturity. Most commonly I engage with
platform engineers and operators. You might be surprised by the disconnect
between them and how developers build and deploy their software. Additionally
there’s, at time, little acknowledgement of their pain points, which means
little knowledge of how a new platform could make them more successful. This
problem surfaces when the platform is finally stood-up (after serious
investment) and adoption lags or application stability decreases due to a
fundamental misunderstandings of the platform and the applications. Building
platforms should be a collaborative effort from the start. That brings security,
development, networking, and more along for the ride. This is especially
important in the world of Kubernetes as containers and container orchestrators
are still completely foreign to many. It’s far too common that a platform gets
setup and the team building and operating it go into defense mode, essentially
telling their customers “too bad” when they realize their application requires
significant rework to run. That said, some defense **is important**, you can’t
and shouldn’t try to solve every edge case on your platform. However, I’d argue
you can get in front a lot of this disconnect by, again, engaging with multiple
aspects of the business up front. So, who is your audience? Is it a large set of
legacy .NET Platform applications? Perhaps you run a huge Java shop with large
(I won’t say monolith ;)) applications that are hard to containerize. Are teams
mostly in containers or VMs but applications aren’t very modern and suffer from
an inability to run multiple replicas or be easily moved across hosts without
tons of involvement? Once you have a sample of your customers, their current
state, and problems you can move onto point 2.

What problems are worth solving implies, you got problems (we all do) but we
have to balance what’s worth solving. Shout out to my CIO friends reading this
post (ha, ha, ha) next time you pick up an issue of CIO weekly use caution with
claims like “Kubernetes SAVES THE WORLD”. As I hope you’ve gathered from this
post, Kubernetes won’t solve your problems. It’s a building block for a larger
solution to solve your problems. If you’re not thoughtful about this, Kubernetes
will instead introduce problems. Consider a group of engineers trying to prove
their product to the market. Often this is a time where the most important thing
is shipping and claiming mindshare from the market. Why waste time introducing a
new platform if you can adequately run on Heroku or App Engine? Heck maybe you
don’t even need a server (joking), go serverless! Your goal was to ship quickly
and your audience is content running on a PaaS, done deal — move on. This is
often countered with notions fo “what if we hit critical mass!?”, “how will we
scale” and “how do we enable future flexibility and requirements the PaaS might
not offer”? This obsession with future problems can be crippling, especially
when you consider what you’re after — claiming market share with a new product.
First, claim the marketshare, because that’s the hard part, you can retrofit
onto a different platform based on real problems in the future. David put it
perfectly:

{{< tweet 1201994124783603712 >}}

Perhaps your organization suffers from lack of portability,  massive software
packages that are hard to update, and scalability issues. Kubernetes doesn’t
solve these. Containerization and breaking apart specific parts of software into
independent services does. Sure, these acts may induce an eventual need for
Kubernetes, but similar to the previous example…should you be worried about that
now? I’m not saying don’t be forward thinking, but … you know … maybe look a
little less far?

The final angle to examine the last example is considering the risk you’re
taking on and your tolerance for it. Let’s assume you are feeling “visionary”
and decide to start a Kubernetes initiative. I don’t condone this, but entertain
me for a moment. Based on the last example, you now need to succeed at the
following.

1. Enabling application teams to understand containers.
2. Containerizing applications and dealing with the papercuts involved.
3. Breaking functionality into independent service for scaling and updatability.
    1. Testing and validating functionality.
    2. Monitoring and tracing the newly complex network layer where IPC has
    moved.
4. Introduce Kubernetes.
5. Build a platform on top of it.
6. Update applications to ensure success on top of Kubernetes (handle
rescheduling, externalize config, etc).
7. Deploy applications to Kubernetes.
8. Setup monitoring, logging, and tracing for workloads.

Reminder, today 1-3 solve your needs of portability, updatability, and scaling.
I’d argue you can focus and see gains with 1-3 and based on learnings inform how
to approach 4-8, which may look totally different. Additionally, you have to
consider that a breakdown in 1-3 can block the success of 4-8. Metaphorically, I
view this like climbing mountains.

{{< img src="https://octetz.s3.us-east-2.amazonaws.com/why-k8s-mtns.png" class="center" >}}

I’ll admit, climbing mountain number 2 would look really cool on your resume,
but it’s not the crux of what you need to solve today. Most importantly, when
assessing this risk, what about your team’s capabilities? Along with knowing
your audience, you need to know your team. Successful Kubernetes implementations
often involve building and leveling up the knowledge of your team. Some
deployments involve creating a group of 30+ people to build and operate the
platform over massive teams of developers. If you’re not careful with this
progression, it can quickly turn into a snowballing mythical-man month
situation.

## Summary

I hope you found this post interesting and entertaining. You’ve read about a
subset of the history that lead to container-based orchestrators, namely
Kubernetes. Most importantly, you’ve examined some considerations for adopting
Kubernetes. All in all, we need to be thoughtful and strategic about what we
should solve and how we should solve it. One of the fun aspects of this industry
is to making informed decisions and place bets on direction. But you have to be
careful to not let non-existent or non-important issue cloud your judgement.
Something I struggle with often. I hope this post has made it clear that if your
Kubernetes initiative fails, don’t be too quick to blame the tech and consider
some introspection on your process and technical evaluation techniques. Lastly,
those of your venturing into this awesome world of platform building in 2020,
best of luck, excited to hear about your success and failures alike!
