# snickerdoodle-build-scripts
SD card boot and root filesystem component build scripts 

## Dependencies
for these scripts the following tools must be previously installed on your system:

```
sudo apt-get --assume-yes install kpartx
sudo apt-get --assume-yes install debootstrap
```


To fetch the prebuilt SD card binaries from which to build an SD card:

```
$ ./fetch_images.sh
```

To build an SD card from an image file
```
$ sudo ./sd_create.sh /dev/sdb snickerdoodle_black.img
```
