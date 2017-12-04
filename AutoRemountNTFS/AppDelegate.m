/*
 *  This file is part of AutoRemountNTFS
 *  Copyright (c) 2017 AutoRemountNTFS's authors
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.

 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.

 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

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

- (void)checkNTFS {
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *file = pipe.fileHandleForReading;

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/sbin/mount";
    task.arguments = @[];
    task.standardOutput = pipe;

    [task launch];

    NSData *data = [file readDataToEndOfFile];
    [file closeFile];

    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
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

            [item setTag:[ntfsDevices count] - 1];

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

                NSString *path = [[NSBundle mainBundle] pathForResource:@"remount" ofType:@"sh"];

                STPrivilegedTask *privilegedTask = [[STPrivilegedTask alloc] init];
                [privilegedTask setLaunchPath:@"/bin/sh"];
                NSArray *args = @[path,
                        devPath,
                        mountPath];
                [privilegedTask setArguments:args];

                OSStatus err = [privilegedTask launch];
                if (err == errAuthorizationSuccess) {
                    [NSThread sleepForTimeInterval:0.5];
                    NSUserNotification *notification2 = [[NSUserNotification alloc] init];
                    notification2.title = NSLocalizedString(@"NTFS Read-only Volume Now Writable", nil);
                    notification2.informativeText = NSLocalizedString(@"Now it is writable.", nil);
                    [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification2];

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
    NSMenuItem *item = (NSMenuItem *) sender;
    NSInteger tag = [item tag];
    NSString *mountPath = ntfsDevices[tag];

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
    NSMenuItem *item = (NSMenuItem *) sender;
    NSInteger tag = [item tag];
    NSString *mountPath = ntfsDevices[tag];

    [[NSWorkspace sharedWorkspace] openFile:[mountPath stringByAppendingString:@"/"]];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
