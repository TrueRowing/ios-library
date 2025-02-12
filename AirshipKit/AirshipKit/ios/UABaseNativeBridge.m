/* Copyright Airship and Contributors */

#import "UABaseNativeBridge.h"
#import "UABaseNativeBridge+Internal.h"
#import "UAUser+Internal.h"
#import "UAWhitelist.h"
#import "UAInboxMessage.h"
#import "UAGlobal.h"
#import "UAUtils+Internal.h"
#import "UAirship+Internal.h"
#import "UAInbox.h"
#import "UAInboxMessage.h"
#import "UAInboxMessageList.h"
#import "UAJavaScriptDelegate.h"
#import "UAWebViewCallData.h"
#import "NSString+UAURLEncoding.h"
#import "UANamedUser.h"
#import "UARuntimeConfig.h"
#import "UAChannel.h"

NSString *const UANativeBridgeUAirshipScheme = @"uairship";
NSString *const UANativeBridgeDismissCommand = @"dismiss";

@implementation UABaseNativeBridge

- (void)populateJavascriptEnvironmentIfWhitelisted:(WKWebView *)webView requestURL:(NSURL *)url completionHandler:(void (^)(void))completionHandler {
    if (![[UAirship shared].whitelist isWhitelisted:url scope:UAWhitelistScopeJavaScriptInterface]) {
        // Don't log in the special case of about:blank URLs
        if (![url.absoluteString isEqualToString:@"about:blank"]) {
            UA_LDEBUG(@"URL %@ is not whitelisted, not populating JS interface", url);
        }
        return completionHandler();
    }
    
    // This will be nil if we are not loading a Rich Push message
    UAInboxMessage *message = [[UAirship inbox].messageList messageForBodyURL:url];
    
    /*
     * Define and initialize our one global
     */
    __block NSString *js = @"var _UAirship = {};";
    
    void (^appendStringGetter)(NSString *, NSString *) = ^(NSString *methodName, NSString *value){
        if (!value) {
            js = [js stringByAppendingFormat:@"_UAirship.%@ = function() {return null;};", methodName];
        } else {
            NSString *encodedValue = [value urlEncodedString];
            js = [js stringByAppendingFormat:@"_UAirship.%@ = function() {return decodeURIComponent(\"%@\");};", methodName, encodedValue];
        }
    };
    
    void (^appendNumberGetter)(NSString *, NSNumber *) = ^(NSString *methodName, NSNumber *value){
        NSNumber *returnValue = value ?: @(-1);
        js = [js stringByAppendingFormat:@"_UAirship.%@ = function() {return %@;};", methodName, returnValue];
    };

    [[UAirship inboxUser] getUserData:^(UAUserData *userData) {
        /*
         * Set the device model.
         */
        appendStringGetter(@"getDeviceModel", [UIDevice currentDevice].model);

        /*
         * Set the Airship user ID.
         */
        appendStringGetter(@"getUserId", userData.username);

        /*
         * Set the current message ID.
         */
        appendStringGetter(@"getMessageId", message.messageID);

        /*
         * Set the current message's title.
         */
        appendStringGetter(@"getMessageTitle", message.title);

        /*
         * Set the named User ID
         */
        appendStringGetter(@"getNamedUser", [UAirship namedUser].identifier);

        /*
         * Set the channel ID
         */
        appendStringGetter(@"getChannelId", [UAirship channel].identifier);

        /*
         * Set the application key
         */
        appendStringGetter(@"getAppKey", [UAirship shared].config.appKey);

        /*
         * Set the current message's sent date
         */
        if (message.messageSent) {
            NSTimeInterval messageSentDateMS = [message.messageSent timeIntervalSince1970] * 1000;
            NSNumber *milliseconds = [NSNumber numberWithDouble:messageSentDateMS];
            appendNumberGetter(@"getMessageSentDateMS", milliseconds);

            NSString *messageSentDate = [[UAUtils ISODateFormatterUTC] stringFromDate:message.messageSent];
            appendStringGetter(@"getMessageSentDate", messageSentDate);

        } else {
            appendNumberGetter(@"getMessageSentDateMS", nil);
            appendStringGetter(@"getMessageSentDate", nil);
        }

        /*
         * Define action/native bridge functionality:
         *
         * UAirship.runAction,
         * UAirship.finishAction
         *
         * See AirshipKit/AirshipResources/UANativeBridge for human-readable source
         */
        NSString *path = [[UAirship resources] pathForResource:@"UANativeBridge" ofType:@""];
        if (path) {
            NSString *bridge = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
            if (bridge) {
                js = [js stringByAppendingString:bridge];
            } else {
                UA_LIMPERR(@"UANativeBridge resource file is not decodable.");
            }
        } else {
            UA_LIMPERR(@"UANativeBridge resource file is missing.");
        }
        
        /*
         * Execute the JS we just constructed.
         */
        [webView evaluateJavaScript:js completionHandler:nil];

        completionHandler();

    } dispatcher:[UADispatcher mainDispatcher]];
}

- (void)performJSDelegateWithData:(UAWebViewCallData *)data webView:(WKWebView *)webView {
    id <UAJavaScriptDelegate> actionJSDelegate = [UAirship shared].actionJSDelegate;
    id <UAJavaScriptDelegate> userJSDDelegate = [UAirship shared].jsDelegate;

    if ([data.url.scheme isEqualToString:@"uairship"]) {
        if ([data.name isEqualToString:@"run-actions"] ||
            [data.name isEqualToString:@"run-basic-actions"] ||
            [data.name isEqualToString:@"run-action-cb"] ||
            [data.name isEqualToString:@"close"]) {
            [self performAsyncJSCallWithDelegate:actionJSDelegate data:data webView:webView];
        } else {
            [self performAsyncJSCallWithDelegate:userJSDDelegate data:data webView:webView];
        }
    }
}

- (void)performAsyncJSCallWithDelegate:(id<UAJavaScriptDelegate>)delegate
                                  data:(UAWebViewCallData *)data
                               webView:(WKWebView *)webView {

    if ([delegate respondsToSelector:@selector(callWithData:withCompletionHandler:)]) {
        __weak WKWebView *weakWebView = webView;
        [delegate callWithData:data withCompletionHandler:^(NSString *script){
            [weakWebView evaluateJavaScript:script completionHandler:nil];
        }];
    }
}

- (nullable NSURL *)createValidPhoneNumberUrlFromUrl:(NSURL *)url {

    NSString *decodedURLString = [url.absoluteString stringByRemovingPercentEncoding];
    NSCharacterSet *characterSet = [[NSCharacterSet characterSetWithCharactersInString:@"+-.0123456789"] invertedSet];
    NSString *strippedNumber = [[decodedURLString componentsSeparatedByCharactersInSet:characterSet] componentsJoinedByString:@""];
    if (!strippedNumber) {
        return nil;
    }
    
    NSString *scheme = [decodedURLString hasPrefix:@"sms"] ? @"sms:" : @"tel:";
    return [NSURL URLWithString:[scheme stringByAppendingString:strippedNumber]];
}


/**
 * Handles a link click.
 * 
 * @param url The link's URL.
 * @returns YES if the link was handled, otherwise NO.
 */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
- (BOOL)handleLinkClick:(NSURL *)url {
    // Send iTunes/Phobos urls to AppStore.app
    if ([[url host] isEqualToString:@"phobos.apple.com"] || [[url host] isEqualToString:@"itunes.apple.com"]) {
        // Set the url scheme to http, as it could be itms which will cause the store to launch twice (undesireable)
        NSString *stringURL = [NSString stringWithFormat:@"http://%@%@", url.host, url.path];
        return [[UIApplication sharedApplication] openURL:[NSURL URLWithString:stringURL]];
    }

    // Send maps.google.com url or maps: to GoogleMaps.app
    if ([[url host] isEqualToString:@"maps.google.com"] || [[url scheme] isEqualToString:@"maps"]) {
        return [[UIApplication sharedApplication] openURL:url];
    }

    // Send www.youtube.com url to YouTube.app
    if ([[url host] isEqualToString:@"www.youtube.com"]) {
         return [[UIApplication sharedApplication] openURL:url];
    }

    // Send mailto: to Mail.app
    if ([[url scheme] isEqualToString:@"mailto"]) {
        return [[UIApplication sharedApplication] openURL:url];
    }

    // Send tel: to Phone.app
    if ([[url scheme] isEqualToString:@"tel"]) {
        NSURL *validPhoneUrl = [self createValidPhoneNumberUrlFromUrl:url];
        return [[UIApplication sharedApplication] openURL:validPhoneUrl];
    }

    // Send sms: to Messages.app
    if ([[url scheme] isEqualToString:@"sms"]) {
        NSURL *validPhoneUrl = [self createValidPhoneNumberUrlFromUrl:url];
        return [[UIApplication sharedApplication] openURL:validPhoneUrl];
    }

    return NO;
}
#pragma GCC diagnostic pop

- (BOOL)isAirshipRequest:(NSURLRequest *)request {
    return [[request.URL scheme] isEqualToString:UANativeBridgeUAirshipScheme];
}

- (BOOL)isWhitelisted:(NSURL *)url {
    return [[UAirship shared].whitelist isWhitelisted:url scope:UAWhitelistScopeJavaScriptInterface];
}

- (BOOL)isWhiteListedAirshipRequest:(NSURLRequest *)request originatingURL:(NSURL *)originatingURL {
    // uairship://command/[<arguments>][?<options>]
    return [self isAirshipRequest:request] && [self isWhitelisted:originatingURL];
}

@end
