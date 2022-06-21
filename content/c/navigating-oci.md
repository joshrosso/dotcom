---
title: "Navigating Remote OCI Artifacts"
weight: 9910
description: OCI has long been the way we package container images. However the standard is being used to host more and more assets. Examples include Helm charts and other configuration. In this post, I'll explore how I navigate, introspect, and mutate OCI artifacts with tooling independent from container runtimes.
date: 2022-04-26
images:
- https://octetz.s3.us-east-2.amazonaws.com/working-with-oci/working-with-oci-title-card.png
---

# Navigating Remote OCI Artifacts

OCI has long been the way we package container images. Over time the standard
has being used to host more and more non container-image assets. Examples
include Helm charts and Carvel packages. In this post, I'll explore how I
navigate, introspect, and copy OCI artifacts with tooling independent from a
container runtime.

## Discovering, Introspecting, and Mutating

For discovering and introspecting artifacts, I use
[crane](https://github.com/google/go-containerregistry/tree/main/cmd/crane). It
is them command line tool companion to the excellent (Go) library
[google/go-containerregistry](https://github.com/google/go-containerregistry). I
use `crane` as my Swiss Army Knife for OCI-related operations. Since
it is independent from a container runtime, I find it especially helpful in
troubleshooting the assets used by runtimes like `containerd`.

If you know which repository/project you want to interact with, another common
struggle is figuring out which tags are available. Most UIs like DockerHub or
Harbor can be a bit obnoxious when trying to determine tags, so I often rely on:

```sh
$ crane ls index.docker.io/nginx
1.20.1-alpine-perl
1.20.1-perl
1.20.2
1.20.2-alpine
1.20.2-alpine-perl
1.20.2-perl
1.21
1.21-alpine
1.21-alpine-perl
1.21-perl
1.21.0
1.21.0-alpine
1.21.0-alpine-perl
1.21.0-perl
1.21.1
1.21.1-alpine
1.21.1-alpine-perl
1.21.1-perl
1.21.3
1.21.3-alpine
1.21.3-alpine-perl
1.21.3-perl
1.21.4
1.21.4-alpine
1.21.4-alpine-perl
1.21.4-perl
1.21.5
1.21.5-alpine
1.21.5-alpine-perl
1.21.5-perl
1.21.6
1.21.6-alpine
1.21.6-alpine-perl
1.21.6-perl
```

> Results above trimmed for brevity.

Now that you've got a list of tags, it would be good to understand what
underlies a tag. Perhaps you don't yet wish to pull down all the contents, but
more so want to look at the image's manifest to better understand its contents.

```sh
$ crane manifest index.docker.io/nginx:1.21.6 | jq
```

The resulting JSON is:

```json
{
  "manifests": [
    {
      "digest": "sha256:83d487b625d8c7818044c04f1b48aabccd3f51c3341fc300926846bca0c439e6",
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "platform": {
        "architecture": "amd64",
        "os": "linux"
      },
      "size": 1570
    },
    {
      "digest": "sha256:3100debc8e667aba0a8284f8cff4b209c941a061f2fb07ea8ab97a96c6caec17",
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "platform": {
        "architecture": "arm",
        "os": "linux",
        "variant": "v5"
      },
      "size": 1570
    },
    {
      "digest": "sha256:b47feab811a96a3b2c6f0ea8c0bb17314c2cf26d7fdbf678764ca1835f96b3c2",
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "platform": {
        "architecture": "arm",
        "os": "linux",
        "variant": "v7"
      },
      "size": 1570
    },
    {
      "digest": "sha256:29fdd887bf4bb4ffe0f3e25893b5c452dad098c95d12cf4ae992542461bcb6f4",
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "platform": {
        "architecture": "arm64",
        "os": "linux",
        "variant": "v8"
      },
      "size": 1570
    },
    {
      "digest": "sha256:5267ae8ff9dc9acdac28e0c927829992d8fb6b12933e73834da07ce61eda6794",
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "platform": {
        "architecture": "386",
        "os": "linux"
      },
      "size": 1570
    },
    {
      "digest": "sha256:91961afa3560f93632f9aa18fb694b9d28c9ac351363adf097dd00dac372a7a2",
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "platform": {
        "architecture": "mips64le",
        "os": "linux"
      },
      "size": 1570
    },
    {
      "digest": "sha256:df9d138f285fc6175a2c1830a8f7fe00908d9a9bdd59c5e7055b428c0f5dc5fe",
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "platform": {
        "architecture": "ppc64le",
        "os": "linux"
      },
      "size": 1570
    },
    {
      "digest": "sha256:8b9b431c2e25ded597edb98589b701f4c1f907739b9491736ae10d9b96acf57f",
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "platform": {
        "architecture": "s390x",
        "os": "linux"
      },
      "size": 1570
    }
  ],
  "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
  "schemaVersion": 2
}
```

In the above manifest list, we can see this image supports multiple
architectures! We now know if a container runtime pulls down this tag, it'll use
the manifest in the list related to its architecture. For example, we'd expect
`containerd` running on an ARM Linux host to pull down
`index.docker.io/nginx@sha256:3100debc8e667aba0a8284f8cff4b209c941a061f2fb07ea8ab97a96c6caec17`.

Now it is time to pull down an actual image. Container images are essentially
file systems that get tar'ed up and stored. We can reveal this easily by
exporting the contents of an OCI artifact.

```sh
$ crane export index.docker.io/nginx:v1.22.5 - | tar xv
```

By default, `crane export` would print the contents to standard out. Instead, we
want to take those `tar` contents and pipe them through `tar xv` to unpack them
on the local file system. Looking at the content, we can see this is a Linux
file system representing the container image.

```sh
$ tree -L2 bin/ var/

bin/
├── bash
├── cat
├── chgrp
├── chmod
├── chown
├── cp
├── dash
├── date
├── dd
├── df
├── dir
├── dmesg
├── dnsdomainname -> hostname
├── domainname -> hostname
├── echo
├── egrep
├── false
├── fgrep
├── findmnt
├── grep
├── gunzip
├── gzexe
├── gzip
├── hostname
├── ln
├── login
├── ls
├── lsblk
├── mkdir
├── mknod
├── mktemp
├── more
├── mount
├── mountpoint
├── mv
├── nisdomainname -> hostname
├── pidof -> /sbin/killall5
├── pwd
├── rbash -> bash
├── readlink
├── rm
├── rmdir
├── run-parts
├── sed
├── sh -> dash
├── sleep
├── stty
├── su
├── sync
├── tar
├── tempfile
├── touch
├── true
├── umount
├── uname
├── uncompress
├── vdir
├── wdctl
├── ypdomainname -> hostname
├── zcat
├── zcmp
├── zdiff
├── zegrep
├── zfgrep
├── zforce
├── zgrep
├── zless
├── zmore
└── znew
var/
├── backups
├── cache
│   ├── apt
│   ├── debconf
│   ├── ldconfig
│   └── nginx
├── lib
│   ├── apt
│   ├── dpkg
│   ├── misc
│   ├── pam
│   ├── systemd
│   └── ucf
├── local
├── lock -> /run/lock
├── log
│   ├── apt
│   ├── btmp
│   ├── dpkg.log
│   ├── faillog
│   ├── lastlog
│   ├── nginx
│   └── wtmp
├── mail
├── opt
├── run -> /run
├── spool
│   └── mail -> ../mail
└── tmp

24 directories, 5 files
```

Copying images between repositories is another useful action. For example,
consider the need to "relocate" an image into a registry you are hosting. A cool
capability of `crane` is its ability to copy all architectures of an image and
maintain all the digest values in the manifest.

```sh
$ crane cp index.docker.io/nginx:1.21.6 index.docker.io/joshrosso/nginx
2022/04/16 07:10:51 Copying from index.docker.io/nginx:1.21.6 to index.docker.io/joshrosso/nginx
2022/04/16 07:10:52 mounted blob: sha256:18f38162c0ce5b57d4967e6b8f863b52243b5796aeb45dcf761c5b21feef0984
2022/04/16 07:10:52 mounted blob: sha256:08c3cb2073f14645ef019dc8e97b90682742fe1d034559189bf579ce783aa9a4
2022/04/16 07:10:52 mounted blob: sha256:2215908dc0a28873ff92070371b1ba3a3cb9d4440d44926c5f29f47a76b17b35
2022/04/16 07:10:52 mounted blob: sha256:c229119241af7b23b121052a1cae4c03e0a477a72ea6a7f463ad7623ff8f274b
2022/04/16 07:10:52 mounted blob: sha256:10e2168f148a67a2fcd6078a3910f234f4378c15d8e2070b079a3ad869e73f15
2022/04/16 07:10:53 mounted blob: sha256:c4ffe9532b5f9277da1c9573e40f56c4b0aacf819b52f4949b7f786b83a24e62
2022/04/16 07:10:53 pushed blob: sha256:12766a6745eea133de9fdcd03ff720fa971fdaf21113d4bc72b417c123b15619
2022/04/16 07:10:53 index.docker.io/joshrosso/nginx@sha256:83d487b625d8c7818044c04f1b48aabccd3f51c3341fc300926846bca0c439e6: digest: sha256:83d487b625d8c7818044c04f1b48aabccd3f51c3341fc300926846bca0c439e6 size: 1570
2022/04/16 07:10:54 mounted blob: sha256:9a41aba0a099ec129c20f41f6370b97daa4c3d4d3edc76ea1863bc5f76f9e5e5
2022/04/16 07:10:54 mounted blob: sha256:37e08739adf0232f999fad1e4495755970c2358af62196d94b5fa1bf58e463e1
2022/04/16 07:10:54 mounted blob: sha256:c6812c30b6d2af8f825b217b6833b5334ec96d6062f399f7de6fefc170440b1d
2022/04/16 07:10:54 mounted blob: sha256:9fe7e8d810837eca0b2abac6ac6ae94c6634bd3e330a68a01b0ab6cec489ebb2
2022/04/16 07:10:54 mounted blob: sha256:02b6b00af27f3727a8015a9b74bec86a59d35bb4edc3176366acd59e10153ddb
2022/04/16 07:10:54 mounted blob: sha256:5cccdc24373a67b0a456476a0bae185f2b9a25a7af8b9d4112eb8d9ab5571360
2022/04/16 07:10:55 pushed blob: sha256:f751231ef8e6225f2fa9c4360c7ec23564037ae914b2f8dda6edf739d2c6d620
2022/04/16 07:10:55 index.docker.io/joshrosso/nginx@sha256:3100debc8e667aba0a8284f8cff4b209c941a061f2fb07ea8ab97a96c6caec17: digest: sha256:3100debc8e667aba0a8284f8cff4b209c941a061f2fb07ea8ab97a96c6caec17 size: 1570
2022/04/16 07:10:56 mounted blob: sha256:f98812e1a494a683a5b3dea593dd2ef305f5f732193044c147f22e44b00164bc
2022/04/16 07:10:56 mounted blob: sha256:f1ece336d115ef70c93df1103198b7b522c5afa79884792da6f67450044dfb05
2022/04/16 07:10:56 mounted blob: sha256:abcb63b666dd6f3bd284849e8d740e078cd526e4d15296963bfa603f3c0316b6
2022/04/16 07:10:56 mounted blob: sha256:31db52cedfb75607a7b1ca98c9e81990d9dd4f60d1cd94a444e4514cc0b02a56
2022/04/16 07:10:56 mounted blob: sha256:b490d27fdd4a7493a6330a4d9abeec5847aa2a09ec5d78f217a25d956eb06c3e
2022/04/16 07:10:56 mounted blob: sha256:3a499091a266645a8a1e0441588584b3d6ed5bedaa53baee988f582eafc2bb01
2022/04/16 07:10:58 pushed blob: sha256:04279fb2ac73e6b6f4d1a92f4563234e83d95ecfa31e63d828f3eef064f27f22
2022/04/16 07:10:58 index.docker.io/joshrosso/nginx@sha256:b47feab811a96a3b2c6f0ea8c0bb17314c2cf26d7fdbf678764ca1835f96b3c2: digest: sha256:b47feab811a96a3b2c6f0ea8c0bb17314c2cf26d7fdbf678764ca1835f96b3c2 size: 1570
2022/04/16 07:10:58 mounted blob: sha256:2203022c5aa978ec114a15a7cdc2c323c65922d3b0a8eab11d50811bb9ae1cfb
2022/04/16 07:10:58 mounted blob: sha256:48ac378ef1156001ee2c1627a92ac394b9dfa757e0f7b4c35dcb3115b5935230
2022/04/16 07:10:59 mounted blob: sha256:b14df6d5899439911e5a79317752118a8d3783cf7426fd211d142e95d87f914e
2022/04/16 07:10:59 mounted blob: sha256:93fe00d45e28ec8d63ba6aa7373414fdaac46f6d644499fefd208a60bda383a0
2022/04/16 07:10:59 mounted blob: sha256:fc0b36f3f49a15683556e499a0c18433e60769a376167b396248240d09bd0529
2022/04/16 07:10:59 mounted blob: sha256:4dd9061d5c104129ba1a14b5ac11d820e303b18672d73b688dcb3feb1adf2fe0
2022/04/16 07:10:59 pushed blob: sha256:fd3d31a07ae69fb788a579676d2c5f4c3dd201f57bcd6c174cd0bd6475886f23
2022/04/16 07:11:00 index.docker.io/joshrosso/nginx@sha256:29fdd887bf4bb4ffe0f3e25893b5c452dad098c95d12cf4ae992542461bcb6f4: digest: sha256:29fdd887bf4bb4ffe0f3e25893b5c452dad098c95d12cf4ae992542461bcb6f4 size: 1570
2022/04/16 07:11:00 mounted blob: sha256:fec59da75229f638ca2878278d3859a1a8b73a20d5c0c043354eb37129ebb8bf
2022/04/16 07:11:00 mounted blob: sha256:f43e9a945a87cbe5e09776aec1972e95ae1197e05aca746a6aff3e654fa71abf
2022/04/16 07:11:00 mounted blob: sha256:c5760117e1158b2f2caa10e67565c19a0a5a5ff9d50326fa7a7353e32138cfcf
2022/04/16 07:11:00 mounted blob: sha256:2d7ddcbfe894748c5af6664edb6a1e3f8571410b7bda2b59d31748f445317676
2022/04/16 07:11:00 mounted blob: sha256:81801a23abac006775adcf44fa5586d618f8c20bd398462ec8bc58c8ef25e41a
2022/04/16 07:11:01 mounted blob: sha256:22eb59c3fa8cdaee9eb80cc3f2e804fca0d2a6c6eab50ae6170645a4cc3bb53d
2022/04/16 07:11:01 pushed blob: sha256:0cccf1347d1e22ac5d82202a0a259a5b1c7449f6db655b3a62d7a2be2c080ca9
2022/04/16 07:11:02 index.docker.io/joshrosso/nginx@sha256:5267ae8ff9dc9acdac28e0c927829992d8fb6b12933e73834da07ce61eda6794: digest: sha256:5267ae8ff9dc9acdac28e0c927829992d8fb6b12933e73834da07ce61eda6794 size: 1570
2022/04/16 07:11:02 mounted blob: sha256:5c2a8045f9de06328ab3d0ff505d990892219b7faee393bc9ac342347fc83d04
2022/04/16 07:11:02 mounted blob: sha256:68b33e7c9b79a86225cc1cceb0823fad18c330ebc7362b4349d8b2935707511b
2022/04/16 07:11:02 mounted blob: sha256:62367482d35b25506e3cc68dc8dd0e224557731b7513a6d6891253fe5215ba07
2022/04/16 07:11:02 mounted blob: sha256:f5981d2499580424d4e141e581514702261f6e69a1a7515d5a9ede0852df75fe
2022/04/16 07:11:02 mounted blob: sha256:c6824efc14a34f28f8c1ed89496eb77fbd141050509fa262f156e3b9efc9587c
2022/04/16 07:11:02 mounted blob: sha256:540b93cfb385a1b39b78d75f7e5232dae89742d78b9ec6ae3c18679bfdd565c0
2022/04/16 07:11:03 pushed blob: sha256:29f287568fce0a3078142cadc265ddfe1d7b25a6757dfb798f79519f89bf2da9
2022/04/16 07:11:04 index.docker.io/joshrosso/nginx@sha256:91961afa3560f93632f9aa18fb694b9d28c9ac351363adf097dd00dac372a7a2: digest: sha256:91961afa3560f93632f9aa18fb694b9d28c9ac351363adf097dd00dac372a7a2 size: 1570
2022/04/16 07:11:04 mounted blob: sha256:ecc74bb8af5a048e1123af0e17d88ef3da1d10951ada79e8e1cc9c0a694245d3
2022/04/16 07:11:04 mounted blob: sha256:79b897a9d589b42bd57e470df470107c267d73fbd1f4301e4c60f296625fae8b
2022/04/16 07:11:04 mounted blob: sha256:f922a9db7b077cd0b774883d903ceb9d44296f62ddd60464325b4964990120cc
2022/04/16 07:11:04 mounted blob: sha256:a152b63bfa87718b52c6147ab7aadeda59c663abb7b6b7325c23559160d7f1ca
2022/04/16 07:11:04 mounted blob: sha256:3f5f53f656bda967800c1ae2d6c59a8f9da4c4f9acb25a88cb6284f8776f46d1e
2022/04/16 07:11:04 mounted blob: sha256:738ca370c4d144edd240215fabd1164ce64b8e7e5e16151a239a7bacd83f7e0f
2022/04/16 07:11:06 pushed blob: sha256:5a6610cace171042d5b01f913cbfa39f278286a6723a976b09afcde57601103b
2022/04/16 07:11:06 index.docker.io/joshrosso/nginx@sha256:df9d138f285fc6175a2c1830a8f7fe00908d9a9bdd59c5e7055b428c0f5dc5fe: digest: sha256:df9d138f285fc6175a2c1830a8f7fe00908d9a9bdd59c5e7055b428c0f5dc5fe size: 1570
2022/04/16 07:11:06 mounted blob: sha256:97996c57525a5d3a24c046a286920e97474273ef2b0115640a6d88faf2d68307
2022/04/16 07:11:06 mounted blob: sha256:854034f6eae36d9a799222f23c2dc953f24d6822772d1de8016157c0d882ef7b
2022/04/16 07:11:06 mounted blob: sha256:ffb22bcde95509bb75f6dd2d69f3fdb5c7471727e4d720b31d92cd297582865c
2022/04/16 07:11:06 mounted blob: sha256:e2160ff505432841419414a1f375ff9e89fda5b83da0822e445aa85de9701f5a
2022/04/16 07:11:07 mounted blob: sha256:db35536e43c9f74e24474abae01ff9e157496d7d135125b5803ab1995cc003ca
2022/04/16 07:11:07 mounted blob: sha256:48c26db9479e034e61c00be5d13b25ba4e60f52f0475dcd4f8a4eddd29946e18
2022/04/16 07:11:07 pushed blob: sha256:b15441cd379824f980596b11a5dd4c68d9e1c0aee3a66714fa8ffbb558d9c15e
2022/04/16 07:11:08 index.docker.io/joshrosso/nginx@sha256:8b9b431c2e25ded597edb98589b701f4c1f907739b9491736ae10d9b96acf57f: digest: sha256:8b9b431c2e25ded597edb98589b701f4c1f907739b9491736ae10d9b96acf57f size: 1570
2022/04/16 07:11:08 index.docker.io/joshrosso/nginx: digest: sha256:2275af0f20d71b293916f1958f8497f987b8d8fd8113df54635f2a5915002bf1 size: 1862
```

Running a quick `diff` against the remote manifests will reveal they are
identical.

```sh
$ COPY=$(crane manifest index.docker.io/joshrosso/nginx) \
    ORIG=$(crane manifest index.docker.io/nginx) \
    diff <(echo ${COPY}) <(echo ${ORIG})
```


## Shoutouts

* [Thanks to the go-containerregistry maintainers for making awesome libraries and
tools like `crane` and `ko`. Ya'll rock.](TODO(https://github.com/google/go-containerregistry/graphs/contributors)
