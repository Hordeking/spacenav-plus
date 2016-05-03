# spacenav-plus

This is a fork of [spacenav-plus](https://github.com/BenBergman/spacenav-plus), which is itself a fork of [spacenav](http://spacenav.sourceforge.net).

Minor modifications have been made to allow compilation on Mac OS X. It has been tested with OS X 10.10 Yosemite. A new libspnav wrapper in Python has been added, as well as a reimplementation of the official 3DconnexionClient Mac OS X SDK.

## spacenavd

This is the driver daemon. It connects to the Space Mouse and sends event using the X Window System, if desired, and using a simple unix socket interface. It reads its configurations from the file `/etc/spnavrc`. An example config can be found in `spacenavd/doc/example-spnavrc`.

Sending the signals `SIGUSR1` or `SIGUSR2` to the daemon causes it to start or stop sending X11 events.

Sending SIGHUP will cause the daemon to reload the configuration file.

For more informations, take a look at `spacenavd/README`.

    cd spacenavd
    ./configure
    make
    sudo make install
    sudo cp doc/example-spnavrc /etc/spnavrc
    sudo ./setup_init

## spnavcfg

This is the optional graphical configuration utility for spacenavd. The required dependencies can be installed with [MacPorts](https://www.macports.org):

    sudo port install xorg-libX11 gtk2 libGLU

You’ll also need the [XQuartz](http://www.xquartz.org) Server for this to work.

    cd spnavcfg
    ./configure
    sudo make install

You will need to configure spacenavd with X11 support:

    ./configure --enable-x11

## libspnav

This is the library used by applications that want to interact with the driver daemon. I've made some small changes. When compiling on Mac OS X, the resulting dynamic library will be built as universal/fat binary.

    cd libspnav
    ./configure
    make
    sudo make install

## libspnav_python

This is my simple Python Wrapper using the libspnav dynamic library, providing pretty much the same interface. An example application is included and can be tested when executing the module itself.

## framework

This is my reimplementation of the official 3DconnexionClient Mac OS X Framework. It uses the original headers but reimplements the basic functionality using the libspnav library. It can be dropped into applications using the official SDK to replace it. This has been tested with Google Earth:

    cd framework
    ./configure --prefix="/Applications/Google\ Earth\ Pro.app/Contents/Frameworks"
    make
    sudo mv "/Applications/Google\ Earth\ Pro.app/Contents/Frameworks/3DconnexionClient.framework /Applications/Google\ Earth\ Pro.app/Contents/Frameworks/3DconnexionClient.framework.original
    sudo make install

## Using it in other programs

None of the programs I use regularly supports building with the spnav library on the Mac out of the box. To start, I’ve hacked support for the spnav library without using X11 into FreeCAD, which already supports spnav on Linux. The patches are in this repository, called `0001-Initialize-spacenavd-without-X11-if-not-available.patch` and `0002-Added-Thread-polling-for-Spaceball-events-generating.patch` in the `patches/FreeCAD` directory. They can be applied cleanly on top of [FreeCAD](https://github.com/FreeCAD/FreeCAD) commit [bfaa8799edba35ae1609edb6205aaeacf37b73ff](https://github.com/FreeCAD/FreeCAD/commit/bfaa8799edba35ae1609edb6205aaeacf37b73ff).

I’ve also modified [the patch from Gert Menke](http://forum.openscad.org/Working-on-SpacePilot-support-need-help-with-rotation-tp13057p13236.html) to suit my setup. You can find `0001-Added-hacky-spnav-lib-support.patch` in the `patches/OpenSCAD` directory. It can be applied cleanly on top of [OpenSCAD](https://github.com/openscad/openscad) commit [50441e85a2d0920af6a1a886b97edc001f4dc0ae](https://github.com/openscad/openscad/commit/50441e85a2d0920af6a1a886b97edc001f4dc0ae).

