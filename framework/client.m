#import "ConnexionClientAPI.h"
#include <mach/mach_time.h>
#include <spnav.h>
#include <pthread.h>

//#define DEBUG
//#define DEBUG_CALLS
//#define ERROR_OUTPUT

#if defined(DEBUG) || defined(DEBUG_CALLS) || defined(ERROR_OUTPUT)
#include <stdio.h>
#endif

// Could theoretically go up to 65535
#define MAX_CLIENTS 42

typedef struct {
    UInt8 registered;
    UInt32 signature;
    UInt8 *name;
    UInt16 mode;
    UInt32 mask;
    UInt32 buttonMask;
} Clients;

// void messageHandler(io_connect_t con, natural_t mType, void *mArgument);
static ConnexionMessageHandlerProc theMessageHandler = NULL;

// void addedHandler(io_connect_t con);
static ConnexionAddedHandlerProc theAddedHandler = NULL;

// void removedHandler(io_connect_t con);
static ConnexionRemovedHandlerProc theRemovedHandler = NULL;

static ConnexionDeviceState device;
static int spnav_opened = 0;

static Clients clients[MAX_CLIENTS];
static int nextUnusedClient = 0;

static pthread_t thread;
static int threadStarted = 0;
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

static void handleEvent(spnav_event *event) {
    if (event->type == SPNAV_EVENT_MOTION) {
        device.command = kConnexionCmdHandleAxis;
        device.time = mach_absolute_time();
        device.buttons8 = 0;
        device.buttons = 0;
        device.axis[0] = -event->motion.x;
        device.axis[1] = -event->motion.y;
        device.axis[2] = -event->motion.z;
        device.axis[3] = -event->motion.rx;
        device.axis[4] = -event->motion.ry;
        device.axis[5] = -event->motion.rz;

        // Send to all clients, regardless of what has been requested
        for (int i = 0; i < MAX_CLIENTS; i++) {
            if (clients[i].registered != 0) {
                device.client = i;
                theMessageHandler(0, kConnexionMsgDeviceState, &device);
            }
        }
    } else if (event->type == SPNAV_EVENT_BUTTON) {
        // We're not yet handling button events
    } else {
#ifdef ERROR_OUTPUT
        fprintf(stderr, "Invalid spacenavd event type: %d\n", event->type);
#endif
    }
}

static void *spacenav_thread(void *argument) {
    spnav_event event;

    for (;;) {
        int result = spnav_wait_event(&event);
        if (result != 0) {
            pthread_mutex_lock(&mutex);
            if (theMessageHandler != NULL) {
                handleEvent(&event);
            }
            pthread_mutex_unlock(&mutex);
        } else {
#ifdef ERROR_OUTPUT
            fprintf(stderr, "Error waiting for spacenavd data!\n");
#endif
            pthread_mutex_lock(&mutex);
            threadStarted = 0;
            pthread_mutex_unlock(&mutex);
            return NULL;
        }
    }

    return NULL;
}

OSErr InstallConnexionHandlers(ConnexionMessageHandlerProc messageHandler, ConnexionAddedHandlerProc addedHandler, ConnexionRemovedHandlerProc removedHandler) {
#ifdef DEBUG_CALLS
    printf("InstallConnexionHandlers(%p, %p, %p);\n", messageHandler, addedHandler, removedHandler);
#endif

    pthread_mutex_lock(&mutex);

    device.version = kConnexionDeviceStateVers;
    device.param = 0;
    device.value = 0;
    device.address = 0;
    device.report[0] = 0;
    device.report[1] = 0;
    device.report[2] = 0;
    device.report[3] = 0;
    device.report[4] = 0;
    device.report[5] = 0;
    device.report[6] = 0;
    device.report[7] = 0;

    nextUnusedClient = 0;
    for (int i = 0; i < MAX_CLIENTS; i++) {
        clients[i].registered = 0;
    }

    theMessageHandler = messageHandler;
    theAddedHandler = addedHandler;
    theRemovedHandler = removedHandler;

    if (messageHandler != NULL) {
        if (spnav_opened == 0) {
#ifdef DEBUG
            printf("opening spacenavd connection...\n");
#endif
            int result = spnav_open();
            if (result != -1) {
                spnav_opened = 1;
            } else {
#ifdef ERROR_OUTPUT
                fprintf(stderr, "Error opening spacenavd connection!\n");
#endif
                pthread_mutex_unlock(&mutex);
                return -1; // could not open spnavd
            }
        } else {
#ifdef DEBUG
            printf("spacenavd connection is already open!\n");
#endif
        }

        if (threadStarted == 0) {
#ifdef DEBUG
            printf("starting spacenavd thread...\n");
#endif
            if (pthread_create(&thread, NULL, spacenav_thread, NULL) != 0) {
#ifdef ERROR_OUTPUT
                fprintf(stderr, "Error starting spacenavd thread!\n");
#endif
                pthread_mutex_unlock(&mutex);
                CleanupConnexionHandlers();
                return -1; // could not start thread
            } else {
                threadStarted = 1;
                pthread_mutex_unlock(&mutex);
                return 0;
            }
        } else {
#ifdef DEBUG
            printf("spacenavd thread already started...\n");
#endif
        }
    }

    pthread_mutex_unlock(&mutex);
    return -1; // did not pass a valid messageHandler
}

void CleanupConnexionHandlers(void) {
#ifdef DEBUG_CALLS
    printf("CleanupConnexionHandlers();\n");
#endif

    pthread_mutex_lock(&mutex);

    if (spnav_opened != 0) {
#ifdef DEBUG
        printf("closing spacenavd connection...\n");
#endif
        if (spnav_close() == -1) {
#ifdef ERROR_OUTPUT
            fprintf(stderr, "Error closing spacenavd connection!\n");
#endif
        } else {
            spnav_opened = 0;
        }
    }

    if (threadStarted != 0) {
#ifdef DEBUG
        printf("canceling spacenavd thread...\n");
#endif
        if (pthread_cancel(thread) != 0) {
#ifdef ERROR_OUTPUT
            fprintf(stderr, "Error canceling spacenavd thread!\n");
#endif
        } else {
            threadStarted = 0;
        }
    }

    nextUnusedClient = 0;
    for (int i = 0; i < MAX_CLIENTS; i++) {
        clients[i].registered = 0;
    }

    pthread_mutex_unlock(&mutex);
}

UInt16 RegisterConnexionClient(UInt32 signature, UInt8 *name, UInt16 mode, UInt32 mask) {
#ifdef DEBUG_CALLS
    printf("RegisterConnexionClient(%d, \"%s\", %d, %d);\n", (unsigned int)signature, name, mode, (unsigned int)mask);
#endif

    pthread_mutex_lock(&mutex);

    int clientID = nextUnusedClient;
    if (clientID >= MAX_CLIENTS) {
#ifdef ERROR_OUTPUT
        fprintf(stderr, "Too many spacenavd clients registered!\n");
#endif
        clientID = MAX_CLIENTS - 1;
    } else {
        nextUnusedClient++;
    }

#ifdef DEBUG
    printf("registered %d as new client ID\n", clientID);
#endif

    clients[clientID].registered = 1;
    clients[clientID].signature = signature;
    clients[clientID].name = name;
    clients[clientID].mode = mode;
    clients[clientID].mask = mask;
    clients[clientID].buttonMask = 0;

    pthread_mutex_unlock(&mutex);

    return clientID;
}

void SetConnexionClientMask(UInt16 clientID, UInt32 mask) {
#ifdef DEBUG_CALLS
    printf("SetConnexionClientMask(%d, %d);\n", clientID, (unsigned int)mask);
#endif

    pthread_mutex_lock(&mutex);

    if (clientID < MAX_CLIENTS) {
        if (clients[clientID].registered == 0) {
#ifdef ERROR_OUTPUT
            fprintf(stderr, "Modifying unregistered spacenavd client ID: %d\n", clientID);
#endif
        }
    } else {
#ifdef ERROR_OUTPUT
        fprintf(stderr, "Trying to modify invalid spacenavd client ID: %d\n", clientID);
#endif
        pthread_mutex_unlock(&mutex);
        return;
    }

    clients[clientID].mask = mask;
    pthread_mutex_unlock(&mutex);
}

void SetConnexionClientButtonMask(UInt16 clientID, UInt32 buttonMask) {
#ifdef DEBUG_CALLS
    printf("SetConnexionClientButtonMask(%d, %d);\n", clientID, (unsigned int)buttonMask);
#endif

    pthread_mutex_lock(&mutex);

    if (clientID < MAX_CLIENTS) {
        if (clients[clientID].registered == 0) {
#ifdef ERROR_OUTPUT
            fprintf(stderr, "Modifying unregistered spacenavd client ID: %d\n", clientID);
#endif
        }
    } else {
#ifdef ERROR_OUTPUT
        fprintf(stderr, "Trying to modify invalid spacenavd client ID: %d\n", clientID);
#endif
        pthread_mutex_unlock(&mutex);
        return;
    }

    clients[clientID].buttonMask = buttonMask;
    pthread_mutex_unlock(&mutex);
}

void UnregisterConnexionClient(UInt16 clientID) {
#ifdef DEBUG_CALLS
    printf("UnregisterConnexionClient(%d);\n", clientID);
#endif

    pthread_mutex_lock(&mutex);

    if (clientID < MAX_CLIENTS) {
        if (clients[clientID].registered == 0) {
#ifdef ERROR_OUTPUT
            fprintf(stderr, "Modifying unregistered spacenavd client ID: %d\n", clientID);
#endif
        } else {
#ifdef DEBUG
            printf("unregistered spacenavd client %d\n", clientID);
#endif
            clients[clientID].registered = 0;
        }
    } else {
#ifdef ERROR_OUTPUT
        fprintf(stderr, "Trying to modify invalid spacenavd client ID: %d\n", clientID);
#endif
    }

    pthread_mutex_unlock(&mutex);
}

OSErr ConnexionControl(UInt32 message, SInt32 param, SInt32 *result) {
#ifdef DEBUG_CALLS
    printf("ConnexionControl(%d, %d, %p);\n", (unsigned int)message, (int)param, result);
#endif

    return -1;
}

OSErr ConnexionClientControl(UInt16 clientID, UInt32 message, SInt32 param, SInt32 *result) {
#ifdef DEBUG_CALLS
    printf("ConnexionClientControl(%d, %d, %d, %p);\n", clientID, (unsigned int)message, (int)param, result);
#endif

    return -1;
}

OSErr ConnexionGetCurrentDevicePrefs(UInt32 deviceID, ConnexionDevicePrefs *prefs) {
#ifdef DEBUG_CALLS
    printf("ConnexionGetCurrentDevicePrefs(%d, %p);\n", (unsigned int)deviceID, prefs);
#endif

    // Return somewhat plausible data, ignoring the deviceID
    prefs->type = kConnexionDevicePrefsType;
    prefs->version = kConnexionDevicePrefsVers;
    prefs->deviceID = kDevID_AnyDevice;
    prefs->reserved1 = 0;
    prefs->appSignature = 0;
    prefs->reserved2 = 0;
    prefs->appName[0] = 0;
    prefs->mainSpeed = 100;
    prefs->zoomOnY = 0;
    prefs->dominant = 0;
    prefs->reserved3 = 0;
    prefs->mapV[0] = 0;
    prefs->mapV[1] = 1;
    prefs->mapV[2] = 2;
    prefs->mapV[3] = 3;
    prefs->mapV[4] = 4;
    prefs->mapV[5] = 5;
    prefs->mapH[0] = 0;
    prefs->mapH[1] = 1;
    prefs->mapH[2] = 2;
    prefs->mapH[3] = 3;
    prefs->mapH[4] = 4;
    prefs->mapH[5] = 5;
    prefs->enabled[0] = 1;
    prefs->enabled[1] = 1;
    prefs->enabled[2] = 1;
    prefs->enabled[3] = 1;
    prefs->enabled[4] = 1;
    prefs->enabled[5] = 1;
    prefs->reversed[0] = 0;
    prefs->reversed[1] = 0;
    prefs->reversed[2] = 0;
    prefs->reversed[3] = 0;
    prefs->reversed[4] = 0;
    prefs->reversed[5] = 0;
    prefs->speed[0] = 100;
    prefs->speed[1] = 100;
    prefs->speed[2] = 100;
    prefs->speed[3] = 100;
    prefs->speed[4] = 100;
    prefs->speed[5] = 100;
    prefs->sensitivity[0] = 100;
    prefs->sensitivity[1] = 100;
    prefs->sensitivity[2] = 100;
    prefs->sensitivity[3] = 100;
    prefs->sensitivity[4] = 100;
    prefs->sensitivity[5] = 100;
    prefs->scale[0] = 1000;
    prefs->scale[1] = 1000;
    prefs->scale[2] = 1000;
    prefs->scale[3] = 1000;
    prefs->scale[4] = 1000;
    prefs->scale[5] = 1000;
    prefs->gamma = 1000;
    prefs->intersect = 1000;

    return 0;
}

OSErr ConnexionSetButtonLabels(UInt8 *labels, UInt16 size) {
#ifdef DEBUG_CALLS
    printf("ConnexionSetButtonLabels(%p, %d);\n", labels, size);
#endif

    // only required for iOS/Android "virtual device" apps

    return 0;
}

