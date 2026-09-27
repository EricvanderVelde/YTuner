# YTuner in a MikroTik RouterOS container
If you own a MikroTik router with container support, you don't need a separate machine for YTuner at all. The router already is the DNS server of your network, so it can point `*.vtuner.com` to a YTuner container running on the router itself.
## Assumptions
- RouterOS v7 on an ARM64 (e.g. RB5009, hAP ax, CCR2004) or x86/CHR device. Tested on RB5009 with RouterOS 7.24.
- A USB/NVMe disk attached to the router (ext4). The image is ~100MB and YTuner writes cache and DB files, so internal flash is not a good place for it.
- Default MikroTik LAN `192.168.88.0/24` on interface `bridge`, with the router at `192.168.88.1`. The container will get `192.168.88.5`. Adjust to your network and pick an address outside your DHCP pool.
- AVRs use the router as their DNS server (default when they get their address from the router's DHCP server).

The files used below are in the [mikrotik](../mikrotik) directory of this repository:
- `Dockerfile` - Debian bookworm-slim based image with the official YTuner release binary, SQLite3 and OpenSSL libraries.
- `entrypoint.sh` - on first start, copies the default `ytuner.ini` and config files to `/data`, then runs YTuner.
- `build.sh` - builds the image and saves it as a tar file ready for RouterOS.

All YTuner state (`ytuner.ini`, `config`, `cache`, `db`) lives in `/data`, which is mounted from the router's disk. Updating or recreating the container keeps your stations, bookmarks and database.

The image's default `ytuner.ini` differs from the release one in:
```
CacheFolderLocation=/data
ConfigFolderLocation=/data
DBFolderLocation=/data
MessageInfoLevel=1
RBCacheType=catPermMemDB
[DNSServer]
Enable=0
```
YTuner's own DNS proxy is disabled because RouterOS static DNS entries do the job.
## That's easy
### 1) Build the image
On any Linux machine with Docker (buildx), no ARM emulation needed:
```
$ cd mikrotik
$ ./build.sh arm64
...
-rw------- 1 user user 106M ytuner-arm64.tar
```
Use `./build.sh amd64` for x86/CHR routers, or to test the image on your PC first:
```
$ docker run --rm -p 8080:80 -v /tmp/ytuner-data:/data ytuner:amd64
```
To build another YTuner release, change `YTUNER_VERSION` in the `Dockerfile`.
### 2) Install the container package
Download the `container` package matching your RouterOS version and architecture and reboot:
```
/tool fetch url="https://download.mikrotik.com/routeros/7.24.4/container-7.24.4-arm64.npk"
/system reboot
```
Check that it's installed with `/system package print`.
>Tip: Do the reboot of this step with `/system reboot` and not by pulling the power cable. A freshly downloaded package may not be written to flash yet and will then be silently lost.
### 3) Enable container device-mode
```
/system device-mode update container=yes
```
Within 5 minutes, confirm this by pressing the reset/mode button or by cold power cycling the router (unplug power for a few seconds). Check with `/system device-mode print` that `container: yes`.
### 4) Network for the container
Give the container its own address in your LAN by putting its veth interface in the LAN bridge:
```
/interface veth add name=veth-ytuner address=192.168.88.5/24 gateway=192.168.88.1
/interface bridge port add bridge=bridge interface=veth-ytuner
```
### 5) Storage and mount
```
/file add name=usb1/ytuner type=directory
/file add name=usb1/ytuner/data type=directory
/file add name=usb1/ytuner/tmp type=directory
/container config set tmpdir=usb1/ytuner/tmp
/container mounts add list=ytuner src=/usb1/ytuner/data dst=/data
```
### 6) Upload the image and create the container
Upload the tar file to the router, e.g. with scp (or drag&drop in WinBox Files):
```
$ scp ytuner-arm64.tar admin@192.168.88.1:usb1/ytuner/ytuner-arm64.tar
```
Create and start the container:
```
/container add name=ytuner file=usb1/ytuner/ytuner-arm64.tar interface=veth-ytuner root-dir=usb1/ytuner/root mountlists=ytuner hostname=ytuner logging=yes start-on-boot=yes
/container start ytuner
```
With `logging=yes`, YTuner output shows up in the router log:
```
/log print where topics~"container"
...
container,info,debug ytuner: *** started /entrypoint.sh
container,info,debug ytuner: YTuner v1.2.6 Copyright (c) 2024 Greg P. (https://github.com/coffeegreg)
container,info,debug ytuner: 27-9-26 08:29:25 : Inf : Starting services...
container,info,debug ytuner: 27-9-26 08:29:25 : Inf : Successfully loaded 10 my stations.
container,info,debug ytuner: 27-9-26 08:29:25 : Inf : Checking local database.
container,info,debug ytuner: 27-9-26 08:29:25 : Inf : Preparing local database This may take a while...
container,info,debug ytuner: 27-9-26 08:29:45 : Inf : Local database is ready.
container,info,debug ytuner: 27-9-26 08:29:45 : Inf : Web Service: listening on: 192.168.88.5:80.
```
Check it from any machine in your LAN:
```
$ curl 'http://192.168.88.5/setupapp/yamaha/asp/BrowseXML/loginXML.asp?token=0'
<EncryptedToken>0123456789ABCDEF</EncryptedToken>
```
### 7) Point vTuner domains to the container
Add a static DNS entry for the vTuner host your AVR uses (e.g. `denon.vtuner.com`, `yamaha.vtuner.com`), or one regexp entry for all of them:
```
/ip dns static add name=denon.vtuner.com address=192.168.88.5
```
or
```
/ip dns static add regexp="(^|\\.)vtuner\\.com\$" address=192.168.88.5
```
and flush the DNS cache:
```
/ip dns cache flush
```
Then power cycle your AVR, so it forgets any cached DNS answers, and open its internet radio.
## Configuration and updates
Edit `ytuner.ini` and your stations file in `usb1/ytuner/data` (WinBox Files, SFTP or SMB share) and restart the container:
```
/container stop ytuner
/container start ytuner
```
To update YTuner, build a new tar file, upload it and recreate the container with the same options as in step 6. Your `/data` stays untouched:
```
/container stop ytuner
/container remove ytuner
/container add name=ytuner file=usb1/ytuner/ytuner-arm64.tar interface=veth-ytuner root-dir=usb1/ytuner/root mountlists=ytuner hostname=ytuner logging=yes start-on-boot=yes
/container start ytuner
```
## Summary
YTuner uses about 11MB of RAM on an RB5009 with `catPermMemDB` cache, so it runs comfortably next to the usual router tasks.
Use the MikroTik documentation to learn more about containers (https://help.mikrotik.com/docs/spaces/ROS/pages/84901929/Container).
