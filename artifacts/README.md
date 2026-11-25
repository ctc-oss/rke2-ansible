# RKE2 Air-Gap / Offline Artifacts

Place the RKE2 release artifacts in this directory on your internet-connected Ansible control host before running the playbook.

Note: Large `.tar.gz`, `.tar.zst`, `.tar`, and `.rpm` files in this directory are ignored by Git via `.gitignore` so you can commit your inventory to a private repository without committing multi-gigabyte binaries.

## Quick Download

Run the helper script from your internet-connected Ansible control host:

```bash
# Downloads default version (v1.36.2+rke2r1) or specify RKE2_VERSION.
# Also downloads local RPM install artifacts to ./artifacts/rpms by default.
RKE2_VERSION="v1.36.2+rke2r1" ./artifacts/download-artifacts.sh
```

Optional environment variables:
- `DOWNLOAD_SELINUX_RPM=true|false` (default `true`)
- `DOWNLOAD_RKE2_RPMS=true|false` (default `true`)
- `DOWNLOAD_NVIDIA_RPMS=true|false` (default `true`; set `false` to skip NVIDIA artifacts)
- `RKE2_CHANNEL=stable|latest` (default `stable`, for SELinux RPM repo)
- `SELINUX_RPM_RELEASEVER=8|9` (default `8`)
- `NVIDIA_DRIVER_STREAM=<major>` (default `580`, used when `DOWNLOAD_NVIDIA_RPMS=true`)
- `NVIDIA_RPM_RELEASEVER=8|9` (default follows `SELINUX_RPM_RELEASEVER`)
- `NVIDIA_DEVICE_PLUGIN_IMAGE=<image>` (default `nvcr.io/nvidia/k8s-device-plugin:v0.20.2`)
- `NVIDIA_DEPENDENCY_REPOS=<comma-separated repo IDs or globs>` (default `rhel*-base*,rhel*-appstream*,rhel*-codereadybuilder*`)

For NVIDIA artifacts, run on an internet-connected RHEL download host with
`dnf` and access to BaseOS, AppStream, and CodeReady Builder repositories
matching the target release and architecture:

```bash
DOWNLOAD_NVIDIA_RPMS=true ./artifacts/download-artifacts.sh
```

Override `NVIDIA_DEPENDENCY_REPOS` if your repository IDs differ. DNF resolves
dependencies in a temporary empty install root, so packages already installed
on the download host do not get omitted. No drivers are installed on that host.
The numeric driver stream uses a precompiled kernel module. Its target kernel
must match the GPU host's kernel; check the downloaded `kmod-nvidia` RPM before
deploying. A successful download does not verify kernel compatibility on nodes.
The NVIDIA device plugin image requires `skopeo` or `ctr` on the download host.

## Expected Files

- `rke2.linux-amd64.tar.gz` — RKE2 binary and systemd unit archive
- `rke2-images.linux-amd64.tar.zst` — Core RKE2 air-gap container images archive
- `rpms/rke2-server-<version>.el<8|9>.<arch>.rpm` — RKE2 server RPM (used on control-plane hosts)
- `rpms/rke2-agent-<version>.el<8|9>.<arch>.rpm` — RKE2 agent RPM (used on worker hosts)
- `rpms/rke2-common-<version>.el<8|9>.<arch>.rpm` — Common runtime dependency RPM
- `rpms/rke2-selinux-<version>.el<8|9>.noarch.rpm` — SELinux policy RPM for RKE2
- `rpms/rancher-rke2-public.key` — Rancher RPM GPG public key imported before local RPM install
- `rpms/nvidia/*.rpm` — NVIDIA driver/runtime RPMs (when `DOWNLOAD_NVIDIA_RPMS=true`)
- `rpms/nvidia/nvidia-cuda-public.key` — NVIDIA CUDA RPM GPG public key
- `rpms/nvidia/nvidia-container-toolkit-public.key` — NVIDIA container toolkit RPM GPG public key
- `nvidia-device-plugin.linux-<arch>.tar` — Airgap NVIDIA Kubernetes device-plugin image

