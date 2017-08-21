//
//  AppDelegate.h
//  AutoRemountNTFS
//
//  Created by MacBookAir on 20/08/2017.
//  Copyright © 2017 Jiege Chen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@end

NSStatusItem *statusItem;
NSMenu *menu;
NSMutableArray<NSString *> *ntfsDevices;

