// AFOAuth1Client.m
//
// Copyright (c) 2011 Mattt Thompson (http://mattt.me/)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFOAuth1Client.h"
#import "AFHTTPRequestOperation.h"

#import <CommonCrypto/CommonHMAC.h>

static const char _b64EncTable[64] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";


NSString * AFURLEncodedStringFromStringWithEncoding(NSString *string, NSStringEncoding encoding) {
    static NSString * const kAFLegalCharactersToBeEscaped = @"?!@#$^&%*+=,:;'\"`<>()[]{}/\\|~ ";
    
    CFStringRef cfString = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)string, NULL, (CFStringRef)kAFLegalCharactersToBeEscaped, CFStringConvertNSStringEncodingToEncoding(encoding));
    
    NSString * retString = CFBridgingRelease(cfString);
    return retString;
    
}
static inline NSString * AFEncodeBase64WithData(NSData *data) {
    const unsigned char * rawData = [data bytes];
    char * out;
    char * result;
    
    int lenght = (int)[data length];
    if (lenght == 0) return nil;
    
    result = (char *)calloc((((lenght + 2) / 3) * 4) + 1, sizeof(char));
    out = result;
    
    while (lenght > 2) {
        *out++ = _b64EncTable[rawData[0] >> 2];
        *out++ = _b64EncTable[((rawData[0] & 0x03) << 4) + (rawData[1] >> 4)];
        *out++ = _b64EncTable[((rawData[1] & 0x0f) << 2) + (rawData[2] >> 6)];
        *out++ = _b64EncTable[rawData[2] & 0x3f];
        
        rawData += 3;
        lenght -= 3;
    }
    
    if (lenght != 0) {
        *out++ = _b64EncTable[rawData[0] >> 2];
        if (lenght > 1) {
            *out++ = _b64EncTable[((rawData[0] & 0x03) << 4) + (rawData[1] >> 4)];
            *out++ = _b64EncTable[(rawData[1] & 0x0f) << 2];
            *out++ = '=';
        } else {
            *out++ = _b64EncTable[(rawData[0] & 0x03) << 4];
            *out++ = '=';
            *out++ = '=';
        }
    }
    
    *out = '\0';
    
    return [NSString stringWithCString:result encoding:NSASCIIStringEncoding];
}

static inline NSDictionary * AFParametersFromQueryString(NSString *queryString) {
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (queryString) {
        NSScanner *parameterScanner = [[NSScanner alloc] initWithString:queryString];
        NSString *name = nil;
        NSString *value = nil;
        
        while (![parameterScanner isAtEnd]) {
            name = nil;        
            [parameterScanner scanUpToString:@"=" intoString:&name];
            [parameterScanner scanString:@"=" intoString:NULL];
            
            value = nil;
            [parameterScanner scanUpToString:@"&" intoString:&value];
            [parameterScanner scanString:@"&" intoString:NULL];		
            
            if (name && value) {
                [parameters setValue:[value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forKey:[name stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            }
        }
    }
    
    return parameters;
}

static inline BOOL AFQueryStringValueIsTrue(NSString *value) {
    return value && [[value lowercaseString] hasPrefix:@"t"];
}

@interface AFOAuth1Token ()
@property (readwrite, nonatomic, copy) NSString *key;
@property (readwrite, nonatomic, copy) NSString *secret;
@property (readwrite, nonatomic, copy) NSString *session;
@property (readwrite, nonatomic, copy) NSString *verifier;
@property (readwrite, nonatomic, retain) NSDate *expiration;
@property (readwrite, nonatomic, assign, getter = canBeRenewed) BOOL renewable;
@end

@implementation AFOAuth1Token
@synthesize key = _key;
@synthesize secret = _secret;
@synthesize session = _session;
@synthesize verifier = _verifier;
@synthesize expiration = _expiration;
@synthesize renewable = _renewable;
@dynamic expired;

- (id)initWithQueryString:(NSString *)queryString {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    NSDictionary *attributes = AFParametersFromQueryString(queryString);
    
    self.key = [attributes objectForKey:@"oauth_token"];
    self.secret = [attributes objectForKey:@"oauth_token_secret"];
    self.session = [attributes objectForKey:@"oauth_session_handle"];
    
    if ([attributes objectForKey:@"oauth_token_duration"]) {
        self.expiration = [NSDate dateWithTimeIntervalSinceNow:[[attributes objectForKey:@"oauth_token_duration"] doubleValue]];
    }
    
    if ([attributes objectForKey:@"oauth_token_renewable"]) {
        self.renewable = AFQueryStringValueIsTrue([attributes objectForKey:@"oauth_token_renewable"]);
    }
    
    return self;
}

@end

#pragma mark -

NSString * const kAFOAuth1Version = @"1.0";
NSString * const kAFApplicationLaunchedWithURLNotification = @"kAFApplicationLaunchedWithURLNotification";
#if __IPHONE_OS_VERSION_MIN_REQUIRED
NSString * const kAFApplicationLaunchOptionsURLKey = @"UIApplicationLaunchOptionsURLKey";
#else
NSString * const kAFApplicationLaunchOptionsURLKey = @"NSApplicationLaunchOptionsURLKey";
#endif

//// TODO: the nonce is not path specific, so fix the signature:
//static inline NSString * AFNounce() {
//    CFUUIDRef uuid = CFUUIDCreate(NULL);
//    CFStringRef string = CFUUIDCreateString(NULL, uuid);
//    CFRelease(uuid);
//    NSString * ret = CFBridgingRelease(string);
//    return ret;
//}

static inline NSString * AFNonceWithPath(NSString *path) {
//    return @"cmVxdWVzdF90bw";
//    return [NSString encodeBase64FromString:[[NSString stringWithFormat:@"%@-%@", path, [[NSDate date] description]] substringWithRange:NSMakeRange(0, 10)]];
//    NSString * string = [[NSString stringWithFormat:@"%@-%@", path, [[NSDate date] description]] substringWithRange:NSMakeRange(0, 10)];
    NSString * string = [NSString stringWithFormat:@"%@-%@", path, [[NSDate date] description]];
    NSData *data = [NSData dataWithBytes:[string UTF8String] length:[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
    return AFEncodeBase64WithData(data);
}


static inline NSString * NSStringFromAFOAuthSignatureMethod(AFOAuthSignatureMethod signatureMethod) {
    switch (signatureMethod) {
        case AFHMACSHA1SignatureMethod:
            return @"HMAC-SHA1";
        case AFPlaintextSignatureMethod:
            return @"PLAINTEXT";
        default:
            return nil;
    }
}

static inline NSString * AFHMACSHA1SignatureWithConsumerSecretAndRequestTokenSecret(NSURLRequest *request, NSString *consumerSecret, NSString *requestTokenSecret, NSStringEncoding stringEncoding) {
    NSString* reqSecret = @"";
    if (requestTokenSecret != nil) {
        reqSecret = requestTokenSecret;
    }
    NSString *secretString = [NSString stringWithFormat:@"%@&%@", consumerSecret, reqSecret];
    NSData *secretStringData = [secretString dataUsingEncoding:stringEncoding];
    
    NSString * sortedQueryString = [[[[[request URL] query] componentsSeparatedByString:@"&"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] componentsJoinedByString:@"&"];
    NSString * encodedQueryString = AFURLEncodedStringFromStringWithEncoding(sortedQueryString, stringEncoding);
    NSString * preQueryString = [[[[request URL] absoluteString] componentsSeparatedByString:@"?"] objectAtIndex:0];
    NSString * encodedPreQueryString = AFURLEncodedStringFromStringWithEncoding(preQueryString, stringEncoding);
    
    NSString *requestString = [NSString stringWithFormat:@"%@&%@&%@", [request HTTPMethod], encodedPreQueryString, encodedQueryString];
    NSData *requestStringData = [requestString dataUsingEncoding:stringEncoding];
    
    // hmac
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CCHmacContext cx;
    CCHmacInit(&cx, kCCHmacAlgSHA1, [secretStringData bytes], [secretStringData length]);
    CCHmacUpdate(&cx, [requestStringData bytes], [requestStringData length]);
    CCHmacFinal(&cx, digest);
    
    // base 64
    NSData *data = [NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
    return AFEncodeBase64WithData(data);
}

static inline NSString * AFPlaintextSignatureWithConsumerSecretAndRequestTokenSecret(NSString *consumerSecret, NSString *requestTokenSecret, NSStringEncoding stringEncoding) {
    // TODO
    return nil;
}

static inline NSString * AFSignatureUsingMethodWithSignatureWithConsumerSecretAndRequestTokenSecret(NSURLRequest *request, AFOAuthSignatureMethod signatureMethod, NSString *consumerSecret, NSString *requestTokenSecret, NSStringEncoding stringEncoding) {
    switch (signatureMethod) {
        case AFHMACSHA1SignatureMethod:
            return AFHMACSHA1SignatureWithConsumerSecretAndRequestTokenSecret(request, consumerSecret, requestTokenSecret, stringEncoding);
        case AFPlaintextSignatureMethod:
            return AFPlaintextSignatureWithConsumerSecretAndRequestTokenSecret(consumerSecret, requestTokenSecret, stringEncoding);
        default:
            return nil;
    }
}


@interface NSURL (AFQueryExtraction)
- (NSString *)AF_getParamNamed:(NSString *)paramName;
@end

@implementation NSURL (AFQueryExtraction)

- (NSString *)AF_getParamNamed:(NSString *)paramName {
    NSString* query = [self query];
    
    NSScanner *scanner = [NSScanner scannerWithString:query];
    NSString *searchString = [[NSString alloc] initWithFormat:@"%@=",paramName];
    [scanner scanUpToString:searchString intoString:nil];
    // ToDo: check if this + [searchString length] works with all urlencoded params?
    NSUInteger startPos = [scanner scanLocation] + [searchString length];
    [scanner scanUpToString:@"&" intoString:nil];
    NSUInteger endPos = [scanner scanLocation];
    return [query substringWithRange:NSMakeRange(startPos, endPos - startPos)];
}

@end

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
@interface AFOAuth1Client () <UIWebViewDelegate>
#else
@interface AFOAuth1Client ()
#endif
@property (readwrite, nonatomic, copy) NSString *key;
@property (readwrite, nonatomic, copy) NSString *secret;
@property (readwrite, nonatomic, copy) NSString *serviceProviderIdentifier;
@property (strong, readwrite, nonatomic) AFOAuth1Token *currentRequestToken;
@property (strong, readwrite, nonatomic) NSURL * callbackUrl;
@property (strong, readwrite, nonatomic) void (^urlResponseBlock)(NSURL * tokenRedirectUrl);

- (void) signCallPerAuthHeaderWithPath:(NSString *)path 
                         andParameters:(NSDictionary *)parameters 
                             andMethod:(NSString *)method ;
- (NSDictionary *) signCallWithHttpGetWithPath:(NSString *)path 
                                 andParameters:(NSDictionary *)parameters 
                                     andMethod:(NSString *)method ;
@end

@implementation AFOAuth1Client
@synthesize key = _key;
@synthesize secret = _secret;
@synthesize serviceProviderIdentifier = _serviceProviderIdentifier;
@synthesize signatureMethod = _signatureMethod;
@synthesize realm = _realm;
@synthesize currentRequestToken = _currentRequestToken;
@synthesize accessToken = _accessToken;
@synthesize oauthAccessMethod = _oauthAccessMethod;

- (id)initWithBaseURL:(NSURL *)url
                  key:(NSString *)clientID
               secret:(NSString *)secret
{
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }
    
    self.key = clientID;
    self.secret = secret;
    
    self.serviceProviderIdentifier = [self.baseURL host];
    
    self.accessToken = nil;
    
    self.oauthAccessMethod = @"HEADER";
    
    return self;
}

- (void)authorizeUsingOAuthWithRequestTokenPath:(NSString *)requestTokenPath
                          userAuthorizationPath:(NSString *)userAuthorizationPath
                                    callbackURL:(NSURL *)callbackURL
                                accessTokenPath:(NSString *)accessTokenPath
                                   accessMethod:(NSString *)accessMethod
                                        success:(void (^)(AFOAuth1Token *accessToken))success 
                                        failure:(void (^)(NSError *error))failure
{
    [self acquireOAuthRequestTokenWithPath:requestTokenPath callback:callbackURL accessMethod:(NSString *)accessMethod success:^(AFOAuth1Token *requestToken) {
        self.callbackUrl = callbackURL;
        self.currentRequestToken = requestToken;
        __block __weak AFOAuth1Client * weakSelf = self;
        [self setUrlResponseBlock:^(NSURL * url) {
            NSLog(@"URL: %@", url);
            
            weakSelf.currentRequestToken.verifier = [url AF_getParamNamed:@"oauth_verifier"];
            
            NSLog(@"verifier %@", self.currentRequestToken.verifier);
            
            [weakSelf acquireOAuthAccessTokenWithPath:accessTokenPath requestToken:self.currentRequestToken accessMethod:(NSString *)accessMethod success:^(AFOAuth1Token * accessToken) {
                if (success) {
                    success(accessToken);
                }
            } failure:failure];
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:kAFApplicationLaunchedWithURLNotification object:nil queue:self.operationQueue usingBlock:^(NSNotification *notification) {
            
            NSURL *url = [[notification userInfo] valueForKey:kAFApplicationLaunchOptionsURLKey];
            if (self.urlResponseBlock)
                self.urlResponseBlock(url);
         }];
        
        NSLog(@"Going out");
        
        NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
        [parameters setValue:requestToken.key forKey:@"oauth_token"];
        NSMutableURLRequest * urlRequest = [self requestWithMethod:@"GET" path:userAuthorizationPath parameters:parameters];
#if __IPHONE_OS_VERSION_MIN_REQUIRED
        if (self.webView) {
            
            self.webView.delegate = self;
            [self.webView loadRequest:urlRequest];
        }
        else {
            [[UIApplication sharedApplication] openURL:[urlRequest URL]];
        }
#else
        [[NSWorkspace sharedWorkspace] openURL:[urlRequest URL]];
#endif
    } failure:failure];
}
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if (webView == self.webView){
        NSLog(@"loading %@",request.URL);
        if ([request.URL.host isEqualToString:self.callbackUrl.host]) {
           if (self.urlResponseBlock) {
                self.urlResponseBlock(request.URL);
                return NO;
            }
        }
    }
    return YES;
}

- (void)acquireOAuthRequestTokenWithPath:(NSString *)path
                                callback:(NSURL *)callbackURL
                            accessMethod:(NSString *)accessMethod
                                 success:(void (^)(AFOAuth1Token *requestToken))success
                                 failure:(void (^)(NSError *error))failure

{    [self clearAuthorizationHeader];
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [parameters setValue:self.key forKey:@"oauth_consumer_key"];
    
    if (self.realm) {
        [parameters setValue:self.realm forKey:@"realm"];
    }
    
    [parameters setValue:AFNonceWithPath(path) forKey:@"oauth_nonce"];
    [parameters setValue:[[NSNumber numberWithInteger:floorf([[NSDate date] timeIntervalSince1970])] stringValue] forKey:@"oauth_timestamp"];
    
    [parameters setValue:NSStringFromAFOAuthSignatureMethod(self.signatureMethod) forKey:@"oauth_signature_method"];
    
    [parameters setValue:kAFOAuth1Version forKey:@"oauth_version"];
    
    [parameters setValue:[callbackURL absoluteString] forKey:@"oauth_callback"];
    
    
    NSMutableURLRequest *mutableRequest = [self requestWithMethod:@"GET" path:path parameters:parameters];
    [mutableRequest setHTTPMethod:accessMethod];
    
    [parameters setValue:AFSignatureUsingMethodWithSignatureWithConsumerSecretAndRequestTokenSecret(mutableRequest, self.signatureMethod, self.secret, nil, self.stringEncoding) forKey:@"oauth_signature"];
    
    [parameters setValue:[callbackURL absoluteString] forKey:@"oauth_callback"];
    
    
    NSArray *sortedComponents = [[AFQueryStringFromParametersWithEncoding(parameters, self.stringEncoding) componentsSeparatedByString:@"&"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSMutableArray *mutableComponents = [NSMutableArray array];
    for (NSString *component in sortedComponents) {
        NSArray *subcomponents = [component componentsSeparatedByString:@"="];
        [mutableComponents addObject:[NSString stringWithFormat:@"%@=\"%@\"", [subcomponents objectAtIndex:0], [subcomponents objectAtIndex:1]]];
    }
    
    NSString *oauthString = [NSString stringWithFormat:@"OAuth %@", [mutableComponents componentsJoinedByString:@", "]];
    
    NSLog(@"OAuth: %@", oauthString);
    
    [self setDefaultHeader:@"Authorization" value:oauthString];
    
    void (^success_block)(AFHTTPRequestOperation*, id);
    void (^failure_block)(AFHTTPRequestOperation*, id);
    
    success_block = ^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Success: %@", operation.responseString);
        
        if (success) {
            AFOAuth1Token *requestToken = [[AFOAuth1Token alloc] initWithQueryString:operation.responseString];
            success(requestToken);
        }
    };
    
    failure_block = ^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failure: %@", operation.responseString);
        if (failure) {
            failure(error);
        }
    };
    
    if ([accessMethod isEqualToString:@"POST"]) {
        [self postPath:path parameters:nil success:success_block failure:failure_block];
    } else {
        [self getPath:path parameters:parameters success:success_block failure:failure_block];
    }
}

- (void)acquireOAuthAccessTokenWithPath:(NSString *)path
                           requestToken:(AFOAuth1Token *)requestToken
                           accessMethod:(NSString *)accessMethod
                                success:(void (^)(AFOAuth1Token *accessToken))success 
                                failure:(void (^)(NSError *error))failure
{
    [self clearAuthorizationHeader];
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [parameters setValue:self.key forKey:@"oauth_consumer_key"];
    [parameters setValue:requestToken.key forKey:@"oauth_token"];
    [parameters setValue:NSStringFromAFOAuthSignatureMethod(self.signatureMethod) forKey:@"oauth_signature_method"];
    [parameters setValue:[[NSNumber numberWithInteger:floorf([[NSDate date] timeIntervalSince1970])] stringValue] forKey:@"oauth_timestamp"];
    [parameters setValue:AFNonceWithPath(path) forKey:@"oauth_nonce"];
    [parameters setValue:kAFOAuth1Version forKey:@"oauth_version"];
    [parameters setValue:requestToken.verifier forKey:@"oauth_verifier"];
    
    if (self.realm) {
        [parameters setValue:self.realm forKey:@"realm"];
    }
    
    NSMutableURLRequest *mutableRequest = [self requestWithMethod:accessMethod path:path parameters:parameters];
    [mutableRequest setHTTPMethod:accessMethod];
    [parameters setValue:AFSignatureUsingMethodWithSignatureWithConsumerSecretAndRequestTokenSecret(mutableRequest, self.signatureMethod, self.secret, requestToken.secret, self.stringEncoding) forKey:@"oauth_signature"];
    
    NSArray *sortedComponents = [[AFQueryStringFromParametersWithEncoding(parameters, self.stringEncoding) componentsSeparatedByString:@"&"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSMutableArray *mutableComponents = [NSMutableArray array];
    for (NSString *component in sortedComponents) {
        NSArray *subcomponents = [component componentsSeparatedByString:@"="];
        [mutableComponents addObject:[NSString stringWithFormat:@"%@=\"%@\"", [subcomponents objectAtIndex:0], [subcomponents objectAtIndex:1]]];
    }
    
    NSString *oauthString = [NSString stringWithFormat:@"OAuth %@", [mutableComponents componentsJoinedByString:@", "]];
    
    NSLog(@"OAuth: %@", oauthString);
    
    [self setDefaultHeader:@"Authorization" value:oauthString];
    
    void (^success_block)(AFHTTPRequestOperation*, id);
    void (^failure_block)(AFHTTPRequestOperation*, id);
    
    success_block = ^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Success: %@", operation.responseString);
        
        if (success) {
            AFOAuth1Token *accessToken = [[AFOAuth1Token alloc] initWithQueryString:operation.responseString];
            self.accessToken = accessToken;
            success(accessToken);
        }
    };
    
    failure_block = ^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Failure: %@", error);
        
        if (failure) {
            failure(error);
        }
    };
    
    if ([accessMethod isEqualToString:@"POST"]) {
        [self postPath:path parameters:parameters success:success_block failure:failure_block];
    } else {
        [self getPath:path parameters:parameters success:success_block failure:failure_block];
    }
}

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
    NSMutableURLRequest *request = [super requestWithMethod:method path:path parameters:parameters];
    [request setHTTPShouldHandleCookies:NO];
    return  request;
}

#pragma mark -

- (void)getPath:(NSString *)path 
     parameters:(NSDictionary *)parameters 
        success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
        failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
    if (self.accessToken) {
        if ([self.oauthAccessMethod isEqualToString:@"GET"])
            parameters = [self signCallWithHttpGetWithPath:path andParameters:parameters andMethod:@"GET"];
        else 
            [self signCallPerAuthHeaderWithPath:path andParameters:parameters andMethod:@"GET"];
    }
    [super getPath:path parameters:parameters success:success failure:failure];
}

- (void)postPath:(NSString *)path 
      parameters:(NSDictionary *)parameters 
         success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
         failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
    if (self.accessToken) {
        if ([self.oauthAccessMethod isEqualToString:@"GET"])
            parameters = [self signCallWithHttpGetWithPath:path andParameters:parameters andMethod:@"POST"];
        else 
            [self signCallPerAuthHeaderWithPath:path andParameters:parameters andMethod:@"POST"];
    }
    [super postPath:path parameters:parameters success:success failure:failure];
}

- (void)putPath:(NSString *)path 
     parameters:(NSDictionary *)parameters 
        success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
        failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
    if (self.accessToken) {
        if ([self.oauthAccessMethod isEqualToString:@"GET"])
            parameters = [self signCallWithHttpGetWithPath:path andParameters:parameters andMethod:@"PUT"];
        else 
            [self signCallPerAuthHeaderWithPath:path andParameters:parameters andMethod:@"PUT"];
    }
    [super putPath:path parameters:parameters success:success failure:failure];
}

- (void)deletePath:(NSString *)path 
        parameters:(NSDictionary *)parameters 
           success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
           failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
    if (self.accessToken) {
        if ([self.oauthAccessMethod isEqualToString:@"GET"])
            parameters = [self signCallWithHttpGetWithPath:path andParameters:parameters andMethod:@"DELETE"];
        else 
            [self signCallPerAuthHeaderWithPath:path andParameters:parameters andMethod:@"DELETE"];
    }
    [super deletePath:path parameters:parameters success:success failure:failure];
}

- (void)patchPath:(NSString *)path 
       parameters:(NSDictionary *)parameters 
          success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
          failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
    if (self.accessToken) {
        if ([self.oauthAccessMethod isEqualToString:@"GET"])
            parameters = [self signCallWithHttpGetWithPath:path andParameters:parameters andMethod:@"PATCH"];
        else 
            [self signCallPerAuthHeaderWithPath:path andParameters:parameters andMethod:@"PATCH"];
    }
    [super patchPath:path parameters:parameters success:success failure:failure];
}

- (NSMutableDictionary *)paramsWithOAuthFromParams:(NSDictionary *)parameters andPath:(NSString*)path{
    NSMutableDictionary *params = nil;
    if (parameters)
        params = [parameters mutableCopy];
    else {
        params = [NSMutableDictionary dictionaryWithCapacity:7];
    }
    [params setValue:self.key forKey:@"oauth_consumer_key"];
    [params setValue:self.accessToken.key forKey:@"oauth_token"];
    [params setValue:NSStringFromAFOAuthSignatureMethod(self.signatureMethod) forKey:@"oauth_signature_method"];
    [params setValue:[[NSNumber numberWithInteger:floorf([[NSDate date] timeIntervalSince1970])] stringValue] forKey:@"oauth_timestamp"];
    [params setValue:AFNonceWithPath(path) forKey:@"oauth_nonce"];
    [params setValue:kAFOAuth1Version forKey:@"oauth_version"];
    return params;
}

- (void) signCallPerAuthHeaderWithPath:(NSString *)path usingParameters:(NSMutableDictionary *)parameters andMethod:(NSString *)method {
    NSMutableURLRequest *request = [self requestWithMethod:@"GET" path:path parameters:parameters];
    [request setHTTPMethod:method];
    [parameters setValue:AFSignatureUsingMethodWithSignatureWithConsumerSecretAndRequestTokenSecret(request, self.signatureMethod, self.secret, self.accessToken.secret, self.stringEncoding) forKey:@"oauth_signature"];
    
    
    NSArray *sortedComponents = [[AFQueryStringFromParametersWithEncoding(parameters, self.stringEncoding) componentsSeparatedByString:@"&"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSMutableArray *mutableComponents = [NSMutableArray array];
    for (NSString *component in sortedComponents) {
        NSArray *subcomponents = [component componentsSeparatedByString:@"="];
        [mutableComponents addObject:[NSString stringWithFormat:@"%@=\"%@\"", [subcomponents objectAtIndex:0], [subcomponents objectAtIndex:1]]];
    }
    
    NSString *oauthString = [NSString stringWithFormat:@"OAuth %@", [mutableComponents componentsJoinedByString:@", "]];
    
    NSLog(@"OAuth: %@", oauthString);
    
     [self setDefaultHeader:@"Authorization" value:oauthString];
}

- (void) signCallPerAuthHeaderWithPath:(NSString *)path andParameters:(NSDictionary *)parameters andMethod:(NSString *)method {
    NSMutableDictionary *params = [self paramsWithOAuthFromParams:parameters andPath:path];
    [self signCallPerAuthHeaderWithPath:path usingParameters:params andMethod:method];
}

- (NSDictionary *) signCallWithHttpGetWithPath:(NSString *)path andParameters:(NSDictionary *)parameters andMethod:(NSString *)method {
    NSMutableDictionary *params = [self paramsWithOAuthFromParams:parameters andPath:path];
    [self signCallPerAuthHeaderWithPath:path usingParameters:params andMethod:method];
    return params;
}

@end
