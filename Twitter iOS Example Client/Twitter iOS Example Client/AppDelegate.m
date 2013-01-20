//
//  AppDelegate.m
//  Twitter iOS Example Client
//
//  Created by Enrico "cHoco" Ghirardi on 01/08/12.
//  Copyright (c) 2012 Just a Dream. All rights reserved.
//

#import "AppDelegate.h"
#import "OAuthWebViewController.h"
#import "AFOAuth1Client.h"
#import "AFJSONRequestOperation.h"

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    NSLog(@"Callback: %@", url);
    
    NSNotification *notification = [NSNotification notificationWithName:kAFApplicationLaunchedWithURLNotification object:nil userInfo:[NSDictionary dictionaryWithObject:url forKey:kAFApplicationLaunchOptionsURLKey]];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
    
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{    
    UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
    OAuthWebViewController *controller = (OAuthWebViewController *)navigationController.topViewController;
/*   self.twitterClient = [[AFOAuth1Client alloc] initWithBaseURL:[NSURL URLWithString:@"https://api.twitter.com/"] key:@"4oFCF0AjP4PQDUaCh5RQ" secret:@"NxAihESVsdUXSUxtHrml2VBHA0xKofYKmmGS01KaSs"];
    
    controller.oauth1Client = self.twitterClient;
    controller.requestTokenPath = @"oauth/request_token";
    controller.userAuthorizationPath = @"oauth/authorize";
    controller.callbackURL = [NSURL URLWithString:@"af-twitter://success"];
    controller.accessTokenPath = @"oauth/access_token"; 
    controller.accessMethod = @"POST";
    controller.successRequestPath = @"1/statuses/user_timeline.json"; */

    
   self.tumblrClient = [[AFOAuth1Client alloc] initWithBaseURL:[NSURL URLWithString:@"http://api.tumblr.com/"] key:@"X1iuXVQzoJJ21gVEudUFgPGedk6a19GdOJ2K0Gc10wGkJTQGi7" secret:@"O0jk94WniCdPEoheUVAAtyyRJhktBSEkNN05SGGX2Po8O4PMK7"];
    self.tumblrClient.oauthAccessMethod = @"GET";
    controller.oauth1Client = self.tumblrClient;
    controller.requestTokenPath = @"http://www.tumblr.com/oauth/request_token";
    controller.userAuthorizationPath = @"http://www.tumblr.com/oauth/authorize";
    controller.callbackURL = [NSURL URLWithString:@"pushvine://tumblr/success"];
    controller.accessTokenPath = @"http://www.tumblr.com/oauth/access_token";
    controller.accessMethod = @"GET";
    controller.successRequestPath = @"v2/user/dashboard";
    
    return YES;
}
/*
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}
*/
@end
