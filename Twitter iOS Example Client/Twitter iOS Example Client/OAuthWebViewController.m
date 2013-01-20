//
//  OAuthWebViewController.m
//  Twitter iOS Example Client
//
//  Created by michael gray on 1/20/13.
//  Copyright (c) 2013 Just a Dream. All rights reserved.
//

#import "OAuthWebViewController.h"
#import "AFOAuth1Client.h"
#import "AFOAuth1Client.h"
#import "AFJSONRequestOperation.h"

@interface OAuthWebViewController ()

@end

@implementation OAuthWebViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.twitterClient.webView = self.webView;
        
}
- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.twitterClient.webView = self.webView;
    
    // Your application will be sent to the background until the user authenticates, and then the app will be brought back using the callback URL
    [_twitterClient authorizeUsingOAuthWithRequestTokenPath:@"oauth/request_token" userAuthorizationPath:@"oauth/authorize" callbackURL:[NSURL URLWithString:@"af-twitter://success"] accessTokenPath:@"oauth/access_token" accessMethod:@"POST" success:^(AFOAuth1Token *accessToken) {
        NSLog(@"Success: %@", accessToken);
        NSLog(@"Your OAuth credentials are now set in the `Authorization` HTTP header");
        
        [_twitterClient registerHTTPOperationClass:[AFJSONRequestOperation class]];
        [_twitterClient getPath:@"1/statuses/user_timeline.json" parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
            NSArray *responseArray = (NSArray *)responseObject;
            [responseArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                NSLog(@"obj: %@", obj);
            }];
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"error: %@", error);
        }];
    } failure:^(NSError *error) {
        NSLog(@"Error: %@", error);
    }];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
