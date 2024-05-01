#!/bin/bash

# copie des elements windows pour virt-v2v

sudo mkdir -p /usr/share/virt-tools /usr/share/virtio-win

sudo cp -a *.exe /usr/share/virt-tools/

sudo cp -a virtio-win.iso /usr/share/virtio-win/

