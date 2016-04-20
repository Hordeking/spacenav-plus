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

That’s it for now.

