# spacenav-plus

This is a fork of [spacenav-plus](https://github.com/BenBergman/spacenav-plus), which is itself a fork of [spacenav](http://spacenav.sourceforge.net).

Minor modifications have been made to allow compilation on Mac OS X. It has been tested with OS X 10.10 Yosemite. The required dependencies for the graphical configuration utility can be installed with [MacPorts](https://www.macports.org):

    sudo port install xorg-libX11 gtk2 libGLU

You’ll also need the [XQuartz](http://www.xquartz.org) Server for this to work.

## Quick Start

There are more readme files provided in the sub-folders. The first thing you’ll want to do is compile the daemon:

    cd spacenavd
    ./configure --prefix=~/test
    make install

You should create a configuration file. Copy the default one and edit it (you have to set a serial port device!):

    sudo cp doc/example-spnavrc /etc/spnavrc
    sudo vim /etc/spnavrc

If you want (and have the required dependencies), compile and install the config utility:

    cd ../spnavcfg
    ./configure --prexix=~/test
    (sudo?) make install

To see if everything works, compile the library and its examples:

    cd ../libspnav
    ./configure --prefix=~/test
    make install
    make examples

Now, start the daemon in one terminal window (to see the verbose output) and the example in another one:

    sudo ~/test/bin/spacenavd -d -v
    ./examples/cube/cube

You can run the spacenavd daemon automatically on boot. Just run `spacenavd/setup_init`, it will create and load `/Library/LaunchDaemons/de.xythobuz.spacenavd.plist` from `spacenavd/launchctl_script`.

## Getting it to work

None of the programs I use regularly supports building with the spnav library on the Mac out of the box. To start, I’ve hacked support for the spnav library without using X11 into FreeCAD, which already supports spnav on Linux. The patches are in this repository, called `0001-Initialize-spacenavd-without-X11-if-not-available.patch` and `0002-Added-Thread-polling-for-Spaceball-events-generating.patch` in the `patches/FreeCAD` directory. They can be applied cleanly on top of [FreeCAD](https://github.com/FreeCAD/FreeCAD) commit [bfaa8799edba35ae1609edb6205aaeacf37b73ff](https://github.com/FreeCAD/FreeCAD/commit/bfaa8799edba35ae1609edb6205aaeacf37b73ff).

I’ve also modified [the patch from Gert Menke](http://forum.openscad.org/Working-on-SpacePilot-support-need-help-with-rotation-tp13057p13236.html) to suit my setup. You can find `0001-Added-hacky-spnav-lib-support.patch` in the `patches/OpenSCAD` directory. It can be applied cleanly on top of [OpenSCAD](https://github.com/openscad/openscad) commit [50441e85a2d0920af6a1a886b97edc001f4dc0ae](https://github.com/openscad/openscad/commit/50441e85a2d0920af6a1a886b97edc001f4dc0ae).

# spacenavd

This is the driver daemon. It connects to the Space Mouse and sends event using the X Window System, if desired, and using a simple unix socket interface. It reads its configurations from the file `/etc/spnavrc`. An example config can be found in `spacenavd/doc/example-spnavrc`.

Sending the signals `SIGUSR1` or `SIGUSR2` to the daemon causes it to start or stop sending X11 events.

Sending SIGHUP will cause the daemon to reload the configuration file.

For more informations, take a look at `spacenavd/README`.

