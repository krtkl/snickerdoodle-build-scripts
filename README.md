# snickerdoodle-build-scripts
SD card boot and root filesystem component build scripts 

To fetch the prebuilt SD card binaries from which to build an SD card:

```
$ ./fetch_images.sh
```

To build an SD card from an image file
```
$ sudo ./sd_create.sh /dev/sdb snickerdoodle_black.img
```
