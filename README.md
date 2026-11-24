# openwrt-image

This is an automated build pipeline for a preconfigured **OpenWrt x86/64 EFI image** designed to run inside an **bhyve guest**, providing a transparent L2 WiFi passthrough bridge.

## Overview

The WiFi support in illumos has long been neglected, thus having thoroughly bitrot.
Native WiFi support on illumos is limited to 802.11a/b/g on outdated WiFi controllers, the most recent supported models being the Intel(R) WiFi Link 4965 and 100/1000/2000/5000/6000 series.

To support modern WiFi chipsets and standards (Wi-Fi 5 / 6 / 6E / 7, WPA3, 160 MHz channels), a lightweight OpenWrt **bhyve guest** using PCI-Passthrough of the physical WiFi controller can be used.
By default, this is configured to act as a transparent WiFi-Bridge that the illumos host can communicate through as if it were a pure Ethernet interface.

This preconfigured OpenWRT image provides the following features:
* **Broad Hardware Coverage:** Bundles all common PCIe WiFi drivers and firmware packages (`iwlwifi` from 5000-series up to AX200/AX210/BE200, `ath9k`, `ath10k`, `ath11k`, `mt7921e`, `mt7925e`, `rtw88`, `rtw89`), providing a single VM image working out of the box on numerous different systems
* **Transparent L2 Bridging:** Bidirectional ingress-to-egress packet redirection between the guests vnic and and the WiFi client interface (`tc mirred`)
* **Host-Driven Provisioning (`qemu-ga`):** Ships without hardcoded credentials. The QEMU Guest Agent is preconfigured on `/dev/vport0p1` so the WiFi network credentials can be set from the host at runtime.
* **No Exposed Services on OpenWRT:** The OpenWRT instance has no network connection of its own, minimizing potential attack surface.
* **Included Diagnostics:** `tcpdump`, `mtr`, `iperf3`, `iftop`, `bmon`, `wavemon`, and `ethtool`.

## Repository Contents

* `build-openwrt-image.sh` – Requests a custom `x86/64` `combined-efi` squashfs image via the official OpenWrt Attended Sysupgrade API (`sysupgrade.openwrt.org`), downloads the resulting `.img.gz`, and writes a `.sha256` checksum file.
* `packages.txt` – List of kernel modules, firmware blobs, and other packages to provide `tc-full`, `qemu-ga`, and CLI network utilities included in the image.
* `uci-defaults.sh` – First-boot provisioning script embedded into `/etc/uci-defaults/` inside the image. Configures `tc mirred` hotplug hooks, disables Wi-Fi power-save, disables OpenWrt routing/DHCP, and enables `qemu-ga`.
* `.github/workflows/build-release.yml` – GitHub Actions workflow to build and publish reproducible release artifacts for packaging.

## Building Locally

Requires `bash`, `curl`, and `python3` (works on OpenIndiana / illumos as well as Linux):

```bash
chmod +x build-openwrt-image.sh
./build-openwrt-image.sh 25.12.6
```

This produces:
* `openwrt-oi-wifi-25.12.6-x86-64-efi.img.gz`
* `openwrt-oi-wifi-25.12.6-x86-64-efi.img.gz.sha256`

## Automated Releases (GitHub Actions)

Push a version tag matching `v*` (e.g. `v25.12.6`) or trigger the **Build OpenWrt OI Wi-Fi Image** workflow manually via the GitHub Actions UI to build and attach the image and SHA-256 checksum to a GitHub Release.

## License

The build scripts and configuration files in this repository are licensed under the **BSD 2-Clause License**.
Prebuilt OpenWrt binary release assets contain upstream OpenWrt and Linux kernel components distributed under their respective open-source licenses (predominantly GPL-2.0).

## Acknowledgments

Initial build scripts, `uci-defaults` hooks, and GitHub Actions workflow were created with assistance from Google Gemini.
