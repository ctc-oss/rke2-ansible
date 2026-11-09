# RKE2 Air-Gap / Offline Artifacts

Place the RKE2 release artifacts in this directory on your internet-connected Ansible control host before running the playbook.

Note: Large `.tar.gz`, `.tar.zst`, `.tar`, and `.rpm` files in this directory are ignored by Git via `.gitignore` so you can commit your inventory to a private repository without committing multi-gigabyte binaries.

## Quick Download

Run the helper script from your internet-connected Ansible control host:

```bash
# Downloads default version (v1.36.6+rke2r1) or specify RKE2_VERSION:
RKE2_VERSION="v1.36.6+rke2r1" ./artifacts/download-artifacts.sh
```

## Expected Files

- `rke2.linux-amd64.tar.gz` — RKE2 binary and systemd unit archive
- `rke2-images.linux-amd64.tar.zst` — Core RKE2 air-gap container images archive

