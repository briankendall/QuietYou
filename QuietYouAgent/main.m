//
//  main.m
//  QuietYou
//

#import <Cocoa/Cocoa.h>
#import "AgentAppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AgentAppDelegate *delegate = [[AgentAppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
        return 0;
    }
}
