#import "ConnexionClientAPI.h"

#include <stdio.h>

OSErr InstallConnexionHandlers(ConnexionMessageHandlerProc messageHandler, ConnexionAddedHandlerProc addedHandler, ConnexionRemovedHandlerProc removedHandler) {
    printf("\nInstallConnexionHandlers(%p, %p, %p);\n\n", messageHandler, addedHandler, removedHandler);
    return -1;
}

void CleanupConnexionHandlers(void) {
    printf("\nCleanupConnexionHandlers();\n\n");
}

UInt16 RegisterConnexionClient(UInt32 signature, UInt8 *name, UInt16 mode, UInt32 mask) {
    printf("\nRegisterConnexionClient(%d, \"%s\", %d, %d);\n\n", (unsigned int)signature, name, mode, (unsigned int)mask);
    return -1;
}

void SetConnexionClientMask(UInt16 clientID, UInt32 mask) {
    printf("\nSetConnexionClientMask(%d, %d);\n\n", clientID, (unsigned int)mask);
}

void SetConnexionClientButtonMask(UInt16 clientID, UInt32 buttonMask) {
    printf("\nSetConnexionClientButtonMask(%d, %d);\n\n", clientID, (unsigned int)buttonMask);
}

void UnregisterConnexionClient(UInt16 clientID) {
    printf("\nUnregisterConnexionClient(%d);\n\n", clientID);
}

OSErr ConnexionControl(UInt32 message, SInt32 param, SInt32 *result) {
    printf("\nConnexionControl(%d, %d, %p);\n\n", (unsigned int)message, (int)param, result);
    return -1;
}

OSErr ConnexionClientControl(UInt16 clientID, UInt32 message, SInt32 param, SInt32 *result) {
    printf("\nConnexionClientControl(%d, %d, %d, %p);\n\n", clientID, (unsigned int)message, (int)param, result);
    return -1;
}

OSErr ConnexionGetCurrentDevicePrefs(UInt32 deviceID, ConnexionDevicePrefs *prefs) {
    printf("\nConnexionGetCurrentDevicePrefs(%d, %p);\n\n", (unsigned int)deviceID, prefs);
    return -1;
}

OSErr ConnexionSetButtonLabels(UInt8 *labels, UInt16 size) {
    printf("\nConnexionSetButtonLabels(%p, %d);\n\n", labels, size);
    return -1;
}

