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
- `DOWNLOAD_NVIDIA_RPMS=true|false` (default `false`)
- `RKE2_CHANNEL=stable|latest` (default `stable`, for SELinux RPM repo)
- `SELINUX_RPM_RELEASEVER=8|9` (default `8`)
- `NVIDIA_DRIVER_STREAM=<major>` (default `580`, used when `DOWNLOAD_NVIDIA_RPMS=true`)
- `NVIDIA_RPM_RELEASEVER=8|9` (default follows `SELINUX_RPM_RELEASEVER`)

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

