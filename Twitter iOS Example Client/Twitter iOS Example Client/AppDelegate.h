//
//  AppDelegate.h
//  Twitter iOS Example Client
//
//  Created by Enrico "cHoco" Ghirardi on 01/08/12.
//  Copyright (c) 2012 Just a Dream. All rights reserved.
//

#import <UIKit/UIKit.h>


@class AFOAuth1Client;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (retain, nonatomic) AFOAuth1Client *twitterClient;
@property (retain, nonatomic) AFOAuth1Client *tumblrClient;

@end
