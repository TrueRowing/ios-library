/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageDefaultDisplayCoordinator.h"
#import "UADispatcher+Internal.h"

#define kUAInAppMessageDefaultDisplayInterval 30

@interface UAInAppMessageDefaultDisplayCoordinator ()

+ (instancetype)coordinatorWithDispatcher:(UADispatcher *)dispatcher notificationCenter:(NSNotificationCenter *)notificationCenter;

@end
