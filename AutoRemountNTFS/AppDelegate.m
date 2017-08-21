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
    
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setTitle:@"NTFS"];
    
    menu = [[NSMenu alloc] init];
    [statusItem setMenu:menu];
    
    ntfsDevices = [[NSMutableArray alloc] init];
    [self checkNTFS];
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
    [menu removeAllItems];
    [ntfsDevices removeAllObjects];
    
    NSTimeInterval time = 10;
    
    for (NSString *line in lines) {
        if ([line rangeOfString:@"ntfs"].location != NSNotFound) {
            NSString *devPath = [line componentsSeparatedByString:@" "][0];
            NSString *mountPath = [line componentsSeparatedByString:@" "][2];
            [ntfsDevices addObject:mountPath];
            
            NSMenuItem *item = [[NSMenuItem alloc] init];
            [item setTitle:[NSString stringWithFormat:@"%@", mountPath]];
            
            [item setTag:[ntfsDevices count]-1];
            
            NSMenuItem *open = [[NSMenuItem alloc] init];
            [open setTitle:NSLocalizedString(@"\tOpen", nil)];
            [open setAction:@selector(open:)];
            NSMenuItem *eject = [[NSMenuItem alloc] init];
            [eject setTitle:NSLocalizedString(@"\tEject", nil)];
            [eject setAction:@selector(eject:)];
            
            [menu addItem:item];
            [menu addItem:open];
            [menu addItem:eject];
            if ([line rangeOfString:@"read-only"].location != NSNotFound) {
                NSUserNotification *notification = [[NSUserNotification alloc] init];
                notification.title = NSLocalizedString(@"New NTFS Read-only Volume Detected", nil);
                notification.informativeText = NSLocalizedString(@"Now making it writable.", nil);
                [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
                
                NSString * path= [[NSBundle mainBundle] pathForResource:@"remount" ofType:@"sh"];
                
                STPrivilegedTask *privilegedTask = [[STPrivilegedTask alloc] init];
                [privilegedTask setLaunchPath:@"/bin/sh"];
                NSArray *args = [NSArray arrayWithObjects:path,
                                 devPath,
                                 mountPath,nil];
                [privilegedTask setArguments:args];
                
                OSStatus err = [privilegedTask launch];
                if (err == errAuthorizationSuccess) {
                    [NSThread sleepForTimeInterval:0.5];
                    NSUserNotification *notification = [[NSUserNotification alloc] init];
                    notification.title = NSLocalizedString(@"NTFS Read-only Volume Now Writable", nil);
                    notification.informativeText = NSLocalizedString(@"Now it is writable.", nil);
                    [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
                    
                    [[NSWorkspace sharedWorkspace] openFile:[mountPath stringByAppendingString:@"/"]];
                } else if (err == errAuthorizationCanceled) {
                    time = 60;
                }
            }
        }
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *item = [[NSMenuItem alloc] init];
    [item setTitle:@"Quit"];
    [item setAction:@selector(terminate:)];
    [menu addItem:item];
    
    [NSTimer scheduledTimerWithTimeInterval:time
                                     target:self
                                   selector:@selector(checkNTFS)
                                   userInfo:nil
                                    repeats:NO];
}

- (void)eject:(id)sender {
    NSMenuItem *item = (NSMenuItem*)sender;
    NSInteger tag = [item tag];
    NSString *mountPath = [ntfsDevices objectAtIndex:tag];
    
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = [NSString stringWithFormat:NSLocalizedString(@"Now ejecting NTFS Volume %@", nil), mountPath];
    notification.informativeText = NSLocalizedString(@"Please wait.", nil);
    [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
    
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/diskutil";
    task.arguments = @[@"eject", mountPath];
    task.standardOutput = pipe;
    
    [task launch];
    
    [file readDataToEndOfFile];
    [file closeFile];
    
    notification = [[NSUserNotification alloc] init];
    notification.title = [NSString stringWithFormat:NSLocalizedString(@"NTFS Volume %@ Is Ejected", nil), mountPath];
    notification.informativeText = NSLocalizedString(@"You can unplug the device now.", nil);
    [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
}

- (void)open:(id)sender {
    NSMenuItem *item = (NSMenuItem*)sender;
    NSInteger tag = [item tag];
    NSString *mountPath = [ntfsDevices objectAtIndex:tag];
    
    [[NSWorkspace sharedWorkspace] openFile:[mountPath stringByAppendingString:@"/"]];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
