/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>

@class UAWebViewCallbackData;

@interface UAWebViewTools : NSObject

/**
 * Transforms a phone number URL into one that UIApplication can handle.
 *
 * @param url A phone number URL.
 * @return A new, sanitized NSURL instance.
 */
+ (NSURL *)createValidPhoneNumberUrlFromUrl:(NSURL *)url;

/**
 * Custom URL scheme handling, for app-specific URL navigation and callback logic.
 *
 * @param wv The webview loading the request.
 * @param request The request.
 * @param navigationType An enumeration of UIWebViewNavigationType.
 * @return `YES` if the URL should be loaded by the webView, `NO` otherwise.
 */
+ (BOOL)webView:(UIWebView *)wv shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType;

/**
 * Used for farming out JavaScript delegate callbacks.
 *
 * @param webView The webview originating the callback.
 * @param url The URL containing the callback arguments/options.
 */
+ (void)performJSDelegate:(UIWebView *)webView url:(NSURL *)url;

@end
