# Lima examples

Default: [`default.yaml`](../pkg/limayaml/default.yaml) (Ubuntu, with containerd/nerdctl)

Distro:
- [`alpine.yaml`](./alpine.yaml): Alpine Linux
- [`archlinux.yaml`](./archlinux.yaml): Arch Linux
- [`debian.yaml`](./debian.yaml): Debian GNU/Linux
- [`fedora.yaml`](./fedora.yaml): Fedora
- [`opensuse.yaml`](./opensuse.yaml): openSUSE Leap
- [`ubuntu.yaml`](./ubuntu.yaml): Ubuntu (same as `default.yaml` but without bogus YAML lines)

Container engines:
- [`docker.yaml`](./docker.yaml): Docker
- [`podman.yaml`](./podman.yaml): Podman
- [`k3s.yaml`](./k3s.yaml): k3s
- [`singularity.yaml`](./singularity.yaml): Singularity
- LXD is installed in the default Ubuntu template, so there is no `lxd.yaml`

Others:
- [`vmnet.yaml`](./vmnet.yaml): enable [`vmnet.framework`](../docs/network.md)

## Usage
Run `limactl start fedora.yaml` to create a Lima instance named "fedora".

To open a shell, run `limactl shell fedora bash` or `LIMA_INSTANCE=fedora lima bash`.
