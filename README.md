# manjaro-cfg

A script for setting up the Manjaro Linux on my laptop.

To prepare an installation image in the USB, enlist your disks via `sudo fdisk -l`, find the path of your USB, and run this command:

> sudo dd bs=4M if=/path/to/manjaro.iso of=/dev/sdX status=progress oflag=sync
