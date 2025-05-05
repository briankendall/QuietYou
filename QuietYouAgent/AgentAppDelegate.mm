//
//  AgentAppDelegate.mm
//  QuietYou
//

#import "AgentAppDelegate.h"

#include "CFTypeHelpers.h"

AgentAppDelegate *_main = nil;

@interface AgentAppDelegate ()
@property (nonatomic, assign) long lastChildCount;
+ (AgentAppDelegate *)main;
- (AXObserverRef)notificationObserver;
- (NSSet<NSString *> *)ignoreStrings;
@end

CFArrayRef copyUIElementChildren(AXUIElementRef parent) {
    CFArrayRef children;
    AXError error = AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute, (const void **)&children);

    if (error != kAXErrorSuccess || !children || CFGetTypeID(children) != CFArrayGetTypeID()) {
        return nullptr;
    }

    return children;
}

CFArrayRef copyElementsWithRole(CFArrayRef elements, CFStringRef targetRole, CFArrayRef targetSubroles = nullptr,
                                CFStringRef targetIdentifier = nullptr) {
    AXError error;
    CFMutableArrayRef result = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);

    for(int i = 0; i < CFArrayGetCount(elements); ++i) {
        AXUIElementRef element = (AXUIElementRef)CFArrayGetValueAtIndex(elements, i);
        CFStringSmartRef role;
        error = AXUIElementCopyAttributeValue(element, kAXRoleAttribute, (CFTypeRef *)&role);

        if (error != kAXErrorSuccess || !role || CFGetTypeID(role) != CFStringGetTypeID()) {
            continue;
        }

        if (CFStringCompare(role, targetRole, 0) != kCFCompareEqualTo) {
            continue;
        }

        if (targetSubroles) {
            CFStringSmartRef subrole;
            error = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute, (CFTypeRef *)&subrole);

            if (error != kAXErrorSuccess || !subrole || CFGetTypeID(subrole) != CFStringGetTypeID()) {
                continue;
            }

            bool subroleMatch = false;
            
            for(int j = 0; j < CFArrayGetCount(targetSubroles); ++j) {
                CFStringRef targetSubrole = (CFStringRef)CFArrayGetValueAtIndex(targetSubroles, j);
                
                if (CFStringCompare(subrole, targetSubrole, 0) == kCFCompareEqualTo) {
                    subroleMatch = true;
                }
            }
            
            if (!subroleMatch) {
                continue;
            }
        }

        if (targetIdentifier) {
            CFStringSmartRef identifier;
            error = AXUIElementCopyAttributeValue(element, kAXIdentifierAttribute, (CFTypeRef *)&identifier);

            if (error != kAXErrorSuccess || !identifier || CFGetTypeID(identifier) != CFStringGetTypeID()) {
                continue;
            }

            if (CFStringCompare(identifier, targetIdentifier, 0) != kCFCompareEqualTo) {
                continue;
            }
        }

        CFArrayAppendValue(result, element);
    }

    return result;
}

CFArrayRef copyChildrenWithRole(AXUIElementRef parent, CFStringRef targetRole, CFArrayRef targetSubroles = nullptr,
                                CFStringRef targetIdentifier = nullptr) {
    CFArraySmartRef children = copyUIElementChildren(parent);

    if (!children) {
        NSLog(@"Error: failed to copy children with role: %@", targetRole);
        return nullptr;
    }

    return copyElementsWithRole(children, targetRole, targetSubroles, targetIdentifier);
}

AXUIElementRef copyFirstChildWithRole(AXUIElementRef parent, CFStringRef targetRole,
                                      CFArrayRef targetSubroles = nullptr, CFStringRef identifier = nullptr) {
    CFArraySmartRef elements = copyChildrenWithRole(parent, targetRole, targetSubroles, identifier);

    if (!elements || CFArrayGetCount(elements) == 0) {
        return nullptr;
    }

    AXUIElementRef result = (AXUIElementRef)CFArrayGetValueAtIndex(elements, 0);
    CFRetain(result);

    return result;
}

bool stringContainsAnySubstringInSet(NSString *string, NSSet<NSString *> *substringSet) {
    for (NSString *substring in substringSet) {
        if ([string rangeOfString:substring options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    
    return NO;
}

bool notificationContainsIgnoreText(AXUIElementRef notificationGroup)
{
    CFArraySmartRef labels = copyChildrenWithRole(notificationGroup, kAXStaticTextRole);

    if (!labels) {
        return false;
    }

    for(int i = 0; i < CFArrayGetCount(labels); ++i) {
        AXUIElementRef label = (AXUIElementRef)CFArrayGetValueAtIndex(labels, i);
        CFStringSmartRef labelText;
        AXError error = AXUIElementCopyAttributeValue(label, kAXValueAttribute, (const void **)&labelText);
        
        if (error != kAXErrorSuccess || !labelText || CFGetTypeID(labelText) != CFStringGetTypeID()) {
            NSLog(@"Error: couldn't get the text from a notification's label");
            continue;
        }
        
        if (stringContainsAnySubstringInSet((__bridge NSString *)labelText.item, [[AgentAppDelegate main] ignoreStrings])) {  
            return true;
        }
    }
    
    return false;
}

void closeAllAnnoyingNotificationsInList(AgentAppDelegate *delegate, AXUIElementRef listGroup) {
    CFArraySmartRef children = copyUIElementChildren(listGroup);
    
    if (!children) {
        return;
    }
    
    delegate.lastChildCount = CFArrayGetCount(children);

    CFArraySmartRef notificationGroups =
        copyElementsWithRole(children, kAXGroupRole, (__bridge CFArrayRef)@[@"AXNotificationCenterAlert", @"AXNotificationCenterBanner"]);

    if (!notificationGroups) {
        return;
    }
    
    for(long i = (long)CFArrayGetCount(notificationGroups) - 1; i >= 0; --i) {
        AXError error;
        AXUIElementRef notificationGroup = (AXUIElementRef)CFArrayGetValueAtIndex(notificationGroups, i);
        
        if (!notificationContainsIgnoreText(notificationGroup)) {
            continue;
        }
        
        CFArraySmartRef actions;
        error = AXUIElementCopyActionNames(notificationGroup, (CFArrayRef *)&actions);
        
        if (error != kAXErrorSuccess || !actions || CFGetTypeID(actions) != CFArrayGetTypeID()) {
            NSLog(@"Error: couldn't get the list of actions for a notification center UI element");
            continue;
        }
        
        for(int j = 0; j < CFArrayGetCount(actions); ++j) {
            CFStringRef action = (CFStringRef)CFArrayGetValueAtIndex(actions, j);
            
            if (CFStringHasPrefix(action, CFSTR("Name:Close"))) {
                NSLog(@"Closing annoying notification with index %ld", i);
                AXUIElementPerformAction(notificationGroup, action);
                break;
            }
        }
    }
}

AXUIElementRef copyWindowNotificationListGroup(AXUIElementRef window) {
    AXUIElementSmartRef hostingView = copyFirstChildWithRole(window, kAXGroupRole, (__bridge CFArrayRef)@[@"AXHostingView"]);

    if (!hostingView) {
        NSLog(@"Error: couldn't get AXHostingView UI element in Notification Center window");
        return nullptr;
    }

    AXUIElementSmartRef scrollArea = copyFirstChildWithRole(hostingView, kAXScrollAreaRole);

    if (!scrollArea) {
        NSLog(@"Error: couldn't get scroll area in Notification Center window");
        return nullptr;
    }

    AXUIElementRef result =
        copyFirstChildWithRole(scrollArea, CFSTR("AXOpaqueProviderGroup"), (__bridge CFArrayRef)@[@"AXOpaqueProviderList"]);

    if (!result) {
        NSLog(@"Error: couldn't get AXOpaqueProviderList UI element in Notification Center window");
    }

    return result;
}

AXUIElementRef copyNotificationCenterWindow(AXUIElementRef notificationCenterElement) {
    return copyFirstChildWithRole(notificationCenterElement, kAXWindowRole, (__bridge CFArrayRef)@[@"AXSystemDialog"]);
}

void observeNotificationList(AgentAppDelegate *delegate, AXUIElementRef listGroup) {
    AXError err = AXObserverAddNotification([delegate notificationObserver], listGroup, kAXLayoutChangedNotification,
                                            NULL);

    if (err != kAXErrorSuccess && err != kAXErrorNotificationAlreadyRegistered) {
        NSLog(@"Error: failed to add Accessibility notification to notification list group, error code: %d", err);
        return;
    }
}

// Function that is fired when the notification center is uninvoked
void notificationCenterNotificationCreated(AXObserverRef observer, AXUIElementRef listGroup, CFStringRef notification,
                                           void *userData) {
    AgentAppDelegate *delegate = [AgentAppDelegate main];

    // Because we're using a kAXLayoutChangedNotification, since there doesn't seem to be any other notification
    // that lets us know when an element has been added to listGroup, we check to make sure the number of children
    // in it has increased before we go looking for annoying notifications to close.

    long childCount;
    AXError error = AXUIElementGetAttributeValueCount(listGroup, kAXChildrenAttribute, &childCount);

    if (error != kAXErrorSuccess) {
        NSLog(@"Error: failed to get number of notifications");
        return;
    }

    if (childCount > delegate.lastChildCount) {
        closeAllAnnoyingNotificationsInList(delegate, listGroup);
    }

    delegate.lastChildCount = childCount;
}

// Function that is fired when the notification center is uninvoked
void notificationCenterWindowCreated(AXObserverRef observer, AXUIElementRef window, CFStringRef notification,
                                     void *userData) {
    AgentAppDelegate *delegate = [AgentAppDelegate main];
    AXUIElementSmartRef listGroup = copyWindowNotificationListGroup(window);

    if (!listGroup) {
        return;
    }

    closeAllAnnoyingNotificationsInList(delegate, listGroup);
    observeNotificationList(delegate, listGroup);
}

@implementation AgentAppDelegate {
    pid_t notificationCenterPID;
    AXUIElementRef notificationCenterElement;
    AXObserverRef windowObserver;
    AXObserverRef notificationObserver;
    NSUserDefaults *appDefaults;
    NSSet<NSString *> *_ignoreStrings;
}

+ (AgentAppDelegate *)main {
    return _main;
}

- (id)init {
    self = [super init];

    if (!self) {
        return nil;
    }
    
    _main = self;
    
    _lastChildCount = 0;
    _ignoreStrings = nil;
    notificationCenterPID = 0;
    notificationCenterElement = nullptr;
    notificationObserver = nullptr;
    windowObserver = nullptr;
    
    appDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"net.briankendall.QuietYou.shared"];
    [appDefaults addObserver:self
                     forKeyPath:@"ignoreStrings"
                        options:NSKeyValueObservingOptionNew
                        context:NULL];

    return self;
}

- (void)releaseElementsAndObservers {
    if (windowObserver) {
        CFRelease(windowObserver);
        windowObserver = nullptr;
    }

    if (notificationObserver) {
        CFRelease(notificationObserver);
        notificationObserver = nullptr;
    }

    if (notificationCenterElement) {
        CFRelease(notificationCenterElement);
        notificationCenterElement = nullptr;
    }
}

- (void)observeNotificationCenter:(pid_t)pid {
    AXError err;

    [self releaseElementsAndObservers];
    self.lastChildCount = 0;

    notificationCenterElement = AXUIElementCreateApplication(pid);

    if (!notificationCenterElement) {
        NSLog(@"Error: failed to create AXUIElementRef for Notification Center");
        return;
    }

    err = AXObserverCreate(pid, notificationCenterWindowCreated, &windowObserver);

    if (err != kAXErrorSuccess || !windowObserver) {
        NSLog(@"Error: failed to create AXObserver for Notification Center. Error: %d", err);
        return;
    }

    err = AXObserverCreate(pid, notificationCenterNotificationCreated, &notificationObserver);

    if (err != kAXErrorSuccess || !notificationObserver) {
        NSLog(@"Error: failed to create AXObserver for Notification Center. Error: %d", err);
        return;
    }

    CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(windowObserver), kCFRunLoopDefaultMode);
    CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(notificationObserver), kCFRunLoopDefaultMode);

    err = AXObserverAddNotification(windowObserver, notificationCenterElement, kAXWindowCreatedNotification, NULL);

    if (err != kAXErrorSuccess) {
        NSLog(@"Error: failed to add Accessibility notification to Notification Center window, error code: %d", err);
        return;
    }

    AXUIElementSmartRef window = copyNotificationCenterWindow(notificationCenterElement);

    if (window) {
        AXUIElementSmartRef listGroup = copyWindowNotificationListGroup(window);

        if (listGroup) {
            closeAllAnnoyingNotificationsInList(self, listGroup);
            observeNotificationList(self, listGroup);
        }
    }
}

- (pid_t)notificationCenterPID {
    NSArray<NSRunningApplication *> *apps =
        [NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.notificationcenterui"];

    if (apps.count == 0) {
        return 0;
    }

    return apps[0].processIdentifier;
}

- (void)ensureNotificationCenterIsObserved {
    pid_t newPID = [self notificationCenterPID];

    if (newPID == notificationCenterPID) {
        return;
    }

    if (notificationCenterPID != 0) {
        NSLog(@"Notification Center restarted! New pid: %d", newPID);
    }

    notificationCenterPID = newPID;
    [self observeNotificationCenter:notificationCenterPID];
}

- (void)closeAllAnnoyingNotifications
{
    pid_t pid = [self notificationCenterPID];
    
    if (pid == 0) {
        return;
    }
    
    notificationCenterElement = AXUIElementCreateApplication(pid);

    if (!notificationCenterElement) {
        NSLog(@"Error: failed to create AXUIElementRef for Notification Center");
        return;
    }
    
    AXUIElementSmartRef window = copyNotificationCenterWindow(notificationCenterElement);

    if (!window) {
        return;
    }
    
    AXUIElementSmartRef listGroup = copyWindowNotificationListGroup(window);

    if (!listGroup) {
        return;
    }
    
    self.lastChildCount = 0;
    closeAllAnnoyingNotificationsInList(self, listGroup);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    if (!AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)
                                           @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES})) {
        [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *timer) {
            NSLog(@"...waiting...");
            if (AXIsProcessTrusted()) {
                [NSApp terminate:self];
            }
        }];
        
        return;
    }

    [self ensureNotificationCenterIsObserved];

    // Unfortunately the workspace notification center won't inform us if Notification Center relaunches, so we have to
    // poll instead:
    [NSTimer scheduledTimerWithTimeInterval:5.0
                                     target:self
                                   selector:@selector(ensureNotificationCenterIsObserved)
                                   userInfo:nil
                                    repeats:true];
}

- (AXObserverRef)notificationObserver {
    return notificationObserver;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self releaseElementsAndObservers];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:@"ignoreStrings"]) {
        NSLog(@"Settings changed");
        _ignoreStrings = nil;
        [self closeAllAnnoyingNotifications];
    }
}

- (NSSet<NSString *> *)ignoreStrings {
    if (!_ignoreStrings) {
        NSArray *inIgnoreStrings = [appDefaults objectForKey:@"ignoreStrings"];
        _ignoreStrings = [NSSet<NSString *> setWithArray:inIgnoreStrings ? inIgnoreStrings : @[]];
    }
    
    return _ignoreStrings;
}

@end
