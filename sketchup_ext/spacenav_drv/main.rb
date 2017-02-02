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

    @connectionOpen = 0

    class ConnectionCloseHelper < Sketchup::AppObserver
      def onUnloadExtension(extension_name)
        if @connectionOpen == 1
          puts("Closing connection to Spacenav Driver...")
          Library::spnav_close()
        end
      end
    end # class ConnectionCloseHelper

    def self.moveCamera(x, y, z, camera)
      #puts("Move #{x}, #{y}, #{z}")
    end

    def self.rotateCamera(x, y, z, camera)
      #puts("Rotate #{x}, #{y}, #{z}")

      scaleFactorY = -250.0
      scaleFactorZ = 250.0

      t = Geom::Transformation.rotation(camera.eye, camera.up, (y / scaleFactorY) * 3.14 / 180.0)
      target = camera.target.transform(t)
      camera.set(camera.eye, target, camera.up)

      # Roll camera
      t = Geom::Transformation.rotation(camera.eye, camera.direction, (z / scaleFactorZ) * 3.14 / 180.0)
      up = camera.up.transform(t)
      camera.set(camera.eye, camera.target, up)
    end

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

      rv = Library::spnav_open()
      if rv != -1
        @connectionOpen = 1

        Sketchup.add_observer(ConnectionCloseHelper.new)

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
