# Sketchup Spacemouse extension

This is a simple proof-of-concept extension for Sketchup (2017) that implements basic first person camera controls.

Axis scaling and inversion can be changed in `spacenav_drv` (search for 'scaleFactor').

The path to libspnav is hard-coded to `/usr/local/lib/libspnav.dylib`, change it if you're not using macOS.

Run `./build.sh` to create 'spacenav_drv.rbz' which can be installed in the Sketchup Extension Manager.

