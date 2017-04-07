# Copyright 2016 Trimble Navigation Limited
# Copyright 2017 Thomas Buck <xythobuz@xythobuz.de>
# Based on the Sketchup Ruby API example (Licensed under the MIT license):
# https://github.com/SketchUp/sketchup-ruby-api-tutorials/tree/master/tutorials/01_hello_cube
# C-Library wrapping based on:
# http://blog.honeybadger.io/use-any-c-library-from-ruby-via-fiddle-the-ruby-standard-librarys-best-kept-secret/
# Camera Rolling based on:
# https://bitbucket.org/thomthom/camera-tools/src/d946acfa6a80a73777d45200d60c960fd901e12d/src/tt_camera/core.rb?at=default&fileviewer=file-view-default

require 'sketchup.rb'

# Used to 'wrap' our libspnav C library
require 'fiddle'
require 'fiddle/import'

module Xythobuz
  module SpacenavDriver

    # Wrapper for Spacenav C-Library, exports the relevant data structures
    # and the spnav_open(), spnav_close and spnav_poll_event(event) calls.
    module Library
      extend Fiddle::Importer

      # TODO path hardcoded for Mac OS X version
      dlload '/usr/local/lib/libspnav.dylib'

      SpnavEventMotion = struct [
        'int type',
        'int x',
        'int y',
        'int z',
        'int rx',
        'int ry',
        'int rz',
        'unsigned int period',
        'int *data'
      ]

      SpnavEventButton = struct [
        'int type',
        'int press',
        'int bnum'
      ]

      extern 'int spnav_open()'
      extern 'int spnav_close()'
      extern 'int spnav_poll_event(SpnavEvent *event)'
    end # module Library

    # Global variable holding connection state. Used for closing the
    # connection on exit, if required, in conjunction with the following
    # helper class/object.
    @connectionOpen = 0
    class ConnectionCloseHelper < Sketchup::AppObserver
      def onUnloadExtension(extension_name)
        if @connectionOpen == 1
          puts("Closing connection to Spacenav Driver...")
          Library::spnav_close()
        end
      end
    end # class ConnectionCloseHelper

    # Called for all spaceball translate events
    def self.moveCamera(x, y, z, camera)
      scaleFactorXm = -10
      scaleFactorYm = 10
      scaleFactorZm = 10
      
      # Scaled vector with translation in camera space
      v = Geom::Vector3d.new(x / scaleFactorXm, y / scaleFactorYm, z / scaleFactorZm)

      # Transform to move from camera space to world space
      t = Geom::Transformation.axes(camera.eye, camera.up * camera.direction, camera.up, camera.direction)

      # Move camera eye and target vectors
      r = v.transform(t)
      eye = camera.eye + r
      target = camera.target + r
      camera.set(eye, target, camera.up)
    end

    # Called for all spaceball rotate events
    def self.rotateCamera(x, y, z, camera)
      scaleFactorXr = 250.0
      scaleFactorYr = -250.0
      scaleFactorZr = -250.0

      # Rotate around camera right axis
      t = Geom::Transformation.rotation(camera.eye, camera.up * camera.direction, (x / scaleFactorXr) * 3.14 / 180.0)
      target = camera.target.transform(t)
      camera.set(camera.eye, target, camera.up)

      # Rotate around camera up axis
      t = Geom::Transformation.rotation(camera.eye, camera.up, (y / scaleFactorYr) * 3.14 / 180.0)
      target = camera.target.transform(t)
      camera.set(camera.eye, target, camera.up)

      # Roll camera around look-at axis
      t = Geom::Transformation.rotation(camera.eye, camera.direction, (z / scaleFactorZr) * 3.14 / 180.0)
      up = camera.up.transform(t)
      camera.set(camera.eye, camera.target, up)
    end

    # Poll a single event and act upon it, if it exists.
    def self.poll_commands
      if @connectionOpen == 0
        return
      end

      event = Library::SpnavEventMotion.malloc
      rv = Library::spnav_poll_event(event)
      if rv != -1
        if event.type == 1
          # Motion event
          camera = Sketchup.active_model.active_view.camera
          moveCamera(event.x, event.y, event.z, camera)
          rotateCamera(event.rx, event.ry, event.rz, camera)
        elsif event.type == 2
          # Button event
          eventBut = Library::SpnavEventButton.new(event)
          puts("Button Event: #{eventBut.bnum} @ #{eventBut.press}")

          # TODO if you want the buttons to do something add relevant code here
        end
      end
    end

    # Note that we again use a load guard to prevent multiple menu items
    # from accidentally being created.
    unless file_loaded?(__FILE__)
      # This calls our code snippet once every 30th of a second...
      frames_per_second = 30.0
      pause_length = 1.0 / frames_per_second

      # Initialize spnav lib
      rv = Library::spnav_open()
      if rv != -1
        # Ensure connection is closed on quit.
        @connectionOpen = 1
        Sketchup.add_observer(ConnectionCloseHelper.new)

        # Poll in specified interval
        puts("Opened connection to Spacenav Driver...")
        UI.start_timer(pause_length, true) {
          poll_commands()
        }
      else
        puts("Error opening Spacenav Driver connection!")
      end

      file_loaded(__FILE__)
    end

  end # module SpacenavDriver
end # module Xythobuz
