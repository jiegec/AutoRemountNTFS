//
//  AppDelegate.m
//  AutoRemountNTFS
//
//  Created by MacBookAir on 20/08/2017.
//  Copyright © 2017 Jiege Chen. All rights reserved.
//

#import "AppDelegate.h"
#import "NSBundle+LoginItem.h"
#import "STPrivilegedTask.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    [[NSBundle mainBundle] addToLoginItems];
    
    [NSTimer scheduledTimerWithTimeInterval:10
                                     target:self
                                   selector:@selector(checkNTFS)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)checkNTFS
{
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/sbin/mount";
    task.arguments = @[];
    task.standardOutput = pipe;
    
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    [file closeFile];
    
    NSString *output = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    NSArray *lines = [output componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        if ([line rangeOfString:@"ntfs"].location != NSNotFound) {
            if ([line rangeOfString:@"read-only"].location != NSNotFound) {
                NSUserNotification *notification = [[NSUserNotification alloc] init];
                notification.title = NSLocalizedString(@"New NTFS Read-only Volume Detected", nil);
                notification.informativeText = NSLocalizedString(@"Now making it writable.", nil);
                [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
                
                NSString * path= [[NSBundle mainBundle] pathForResource:@"remount" ofType:@"sh"];
                
                STPrivilegedTask *privilegedTask = [[STPrivilegedTask alloc] init];
                [privilegedTask setLaunchPath:@"/bin/sh"];
                NSArray *args = [NSArray arrayWithObjects:path,
                                 [line componentsSeparatedByString:@" "][0],
                                 [line componentsSeparatedByString:@" "][2],nil];
                [privilegedTask setArguments:args];
                
                OSStatus err = [privilegedTask launch];
                if (err == errAuthorizationSuccess) {
                    NSUserNotification *notification = [[NSUserNotification alloc] init];
                    notification.title = NSLocalizedString(@"NTFS Read-only Volume Now Writable", nil);
                    notification.informativeText = NSLocalizedString(@"Now it is writable.", nil);
                    [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
                }
            }
        }
    }
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
