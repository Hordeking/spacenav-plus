#!/usr/bin/env python

# -----------------------------------------------------------------------------
#
# Usage:
#
# enum:
#     SPNAV_EVENT_ANY
#     SPNAV_EVENT_MOTION
#     SPNAV_EVENT_BUTTON
#
# structure SpnavMotionEvent:
#     int x, y, z
#     int rx, ry, rz
#     uint period
#     int* data
#
# structure SpnavButtonEvent:
#     int press, bnum
#
# union SpnavEvent:
#     int type
#     SpnavMotionEvent motion
#     SpnavButtonEvent button
#
# Open connection to the daemon via AF_UNIX socket
# Returns 'True' on error, 'False' on success
# def spnavOpen()
#
# Close connection to the daemon
# Returns 'True' on error, 'False' on success
# def spnavClose()
#
# Blocks waiting for space-nav events
# Returns 'None' on error or an event on success
# def spnavWaitEvent()
#
# Checks for the availability of space-nav events (non-blocking)
# Returns 'None' if no event available or an event on success
# def spnavPollEvent()
#
# Removes any pending events from the specified type, or all pending
# events if the type argument is SPNAV_EVENT_ANY. Returns the number
# of removed events.
# def spnavRemoveEvents(eventType)
#
# -----------------------------------------------------------------------------

from sys import platform
from ctypes import (Structure, Union, c_int, c_uint, POINTER, CDLL, byref)

# -----------------------------------------------------------------------------
# Try to load dynamic library

if platform == "linux" or platform == "linux2":
    libspnav = CDLL('/usr/local/lib/libspnav.so')
elif platform == "darwin":
    libspnav = CDLL('/usr/local/lib/libspnav.dylib')

# -----------------------------------------------------------------------------
# Definitions for data structures of spnav library

# enum {
#     SPNAV_EVENT_ANY = 0,	/* used by spnav_remove_events() */
#     SPNAV_EVENT_MOTION = 1,
#     SPNAV_EVENT_BUTTON = 2	/* includes both press and release */
# };
(SPNAV_EVENT_ANY, SPNAV_EVENT_MOTION, SPNAV_EVENT_BUTTON) = (0, 1, 2)

# struct spnav_event_motion {
#     int type;
#     int x, y, z;
#     int rx, ry, rz;
#     unsigned int period;
#     int *data;
# };
class SpnavMotionEvent(Structure): pass
SpnavMotionEvent._fields_ = [
    ('type', c_int),
    ('x', c_int),
    ('y', c_int),
    ('z', c_int),
    ('rx', c_int),
    ('ry', c_int),
    ('rz', c_int),
    ('period', c_uint),
    ('data', POINTER(c_uint))
]

# struct spnav_event_button {
#     int type;
#     int press;
#     int bnum;
# };
class SpnavButtonEvent(Structure): pass
SpnavButtonEvent._fields_ = [
    ('type', c_int),
    ('press', c_int),
    ('bnum', c_int)
]

# typedef union spnav_event {
#     int type;
#     struct spnav_event_motion motion;
#     struct spnav_event_button button;
# } spnav_event;
class SpnavEvent(Union): pass
SpnavEvent._fields_ = [
    ('type', c_int),
    ('motion', SpnavMotionEvent),
    ('button', SpnavButtonEvent)
]

# -----------------------------------------------------------------------------
# Actual python wrapper methods

# int spnav_open(void);
libspnav.spnav_open.restype = c_int
#libspnav.spnav_open.argtypes = [None]

# Open connection to the daemon via AF_UNIX socket
# Returns 'True' on error, 'False' on success
def spnavOpen():
    result = libspnav.spnav_open()
    if result == -1:
        return True
    return False

# int spnav_close(void);
libspnav.spnav_close.restype = c_int
#libspnav.spnav_close.argtypes = [None]

# Close connection to the daemon
# Returns 'True' on error, 'False' on success
def spnavClose():
    result = libspnav.spnav_close()
    if result == -1:
        return True
    return False

# int spnav_wait_event(spnav_event *event);
libspnav.spnav_wait_event.restype = c_int
libspnav.spnav_wait_event.argtypes = [POINTER(SpnavEvent)]

# Blocks waiting for space-nav events
# Returns 'None' on error or an event on success
def spnavWaitEvent():
    event = SpnavEvent(SPNAV_EVENT_ANY,
                  SpnavMotionEvent(0, 0, 0, 0, 0, 0, 0, 0, None),
                  SpnavButtonEvent(0, 0, 0))
    result = libspnav.spnav_wait_event(byref(event))
    if result == 0:
        return None
    return event

# int spnav_poll_event(spnav_event *event);
libspnav.spnav_poll_event.restype = c_int
libspnav.spnav_poll_event.argtypes = [POINTER(SpnavEvent)]

# Checks for the availability of space-nav events (non-blocking)
# Returns 'None' if no event available or an event on success
def spnavPollEvent():
    event = SpnavEvent(SPNAV_EVENT_ANY,
                  SpnavMotionEvent(0, 0, 0, 0, 0, 0, 0, 0, None),
                  SpnavButtonEvent(0, 0, 0))
    result = libspnav.spnav_poll_event(byref(event))
    if result == 0:
        return None
    return event

# int spnav_remove_events(int type);
libspnav.spnav_remove_events.restype = c_int
libspnav.spnav_remove_events.argtypes = [c_int]

# Removes any pending events from the specified type, or all pending
# events if the type argument is SPNAV_EVENT_ANY. Returns the number
# of removed events.
def spnavRemoveEvents(eventType):
    return libspnav.spnav_remove_events(eventType)

# -----------------------------------------------------------------------------
# Simple Hello-World to test the library and the wrapper

import signal
import time

def signalHandler(signal, frame):
    global interrupted
    interrupted = True

def main():
    print "Trying to open connection..."
    if spnavOpen() == True:
        print "Error opening connection!"
        exit()

    print "Entering polling loop..."
    signal.signal(signal.SIGINT, signalHandler)
    global interrupted
    interrupted = False
    while interrupted == False:
        event = spnavPollEvent()
        if event != None:
            if event.type == SPNAV_EVENT_BUTTON:
                print "Got a button event:"
                print "    {} {}".format(event.button.bnum, event.button.press)
            elif event.type == SPNAV_EVENT_MOTION:
                print "Got a motion event:"
                print "    {} {} {}".format(event.motion.x, event.motion.y, event.motion.z)
                print "    {} {} {}".format(event.motion.rx, event.motion.ry, event.motion.rz)
            elif event.type == SPNAV_EVENT_ANY:
                print "Got any event?!"
            else:
                print "Got an unknown event?!"
        time.sleep(0.01)

    print "Closing connection..."
    if spnavClose() == True:
        print "Error closing connection!"

if __name__ == "__main__":
    main()

