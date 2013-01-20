//
//  OAuthWebViewController.h
//  Twitter iOS Example Client
//
//  Created by michael gray on 1/20/13.
//  Copyright (c) 2013 Just a Dream. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AFOAuth1Client;
@interface OAuthWebViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (strong, nonatomic) AFOAuth1Client *twitterClient;

@end
