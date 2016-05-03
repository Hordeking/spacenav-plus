#import "ConnexionClientAPI.h"
#include <spnav.h>

#define DEBUG
#define DEBUG_CALLS
#define ERROR_OUTPUT

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

static int spnav_opened = 0;

static Clients clients[MAX_CLIENTS];
static int nextUnusedClient = 0;

OSErr InstallConnexionHandlers(ConnexionMessageHandlerProc messageHandler, ConnexionAddedHandlerProc addedHandler, ConnexionRemovedHandlerProc removedHandler) {
#ifdef DEBUG_CALLS
    printf("InstallConnexionHandlers(%p, %p, %p);\n", messageHandler, addedHandler, removedHandler);
#endif

    nextUnusedClient = 0;
    for (int i = 0; i < MAX_CLIENTS; i++) {
        clients[i].registered = 0;
    }

    theMessageHandler = messageHandler;
    theAddedHandler = addedHandler;
    theRemovedHandler = removedHandler;

    if (messageHandler != NULL) {
        if (spnav_opened != 0) {
#ifdef DEBUG
            printf("spacenavd connection is already open!\n");
#endif
            return 0;
        }

#ifdef DEBUG
        printf("opening spacenavd connection...\n");
#endif
        int result = spnav_open();
        if (result != -1) {
            spnav_opened = 1;
            return 0;
        } else {
#ifdef ERROR_OUTPUT
            fprintf(stderr, "Error opening spacenavd connection!\n");
#endif
            return -1; // could not open spnavd
        }
    }

    return -1; // did not pass a valid messageHandler
}

void CleanupConnexionHandlers(void) {
#ifdef DEBUG_CALLS
    printf("CleanupConnexionHandlers();\n");
#endif

    if (spnav_opened != 0) {
#ifdef DEBUG
        printf("closing spacenavd connection...\n");
#endif
        if (spnav_close() == -1) {
#ifdef ERROR_OUTPUT
            fprintf(stderr, "Error closing spacenavd connection!\n");
#endif
        }
        spnav_opened = 0;
    }

    nextUnusedClient = 0;
    for (int i = 0; i < MAX_CLIENTS; i++) {
        clients[i].registered = 0;
    }
}

UInt16 RegisterConnexionClient(UInt32 signature, UInt8 *name, UInt16 mode, UInt32 mask) {
#ifdef DEBUG_CALLS
    printf("RegisterConnexionClient(%d, \"%s\", %d, %d);\n", (unsigned int)signature, name, mode, (unsigned int)mask);
#endif

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

    return clientID;
}

void SetConnexionClientMask(UInt16 clientID, UInt32 mask) {
#ifdef DEBUG_CALLS
    printf("SetConnexionClientMask(%d, %d);\n", clientID, (unsigned int)mask);
#endif

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
        return;
    }

    clients[clientID].mask = mask;
}

void SetConnexionClientButtonMask(UInt16 clientID, UInt32 buttonMask) {
#ifdef DEBUG_CALLS
    printf("SetConnexionClientButtonMask(%d, %d);\n", clientID, (unsigned int)buttonMask);
#endif

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
        return;
    }

    clients[clientID].buttonMask = buttonMask;
}

void UnregisterConnexionClient(UInt16 clientID) {
#ifdef DEBUG_CALLS
    printf("UnregisterConnexionClient(%d);\n", clientID);
#endif

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

