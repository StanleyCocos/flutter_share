//
//  ShareHelper.m
//  ShareDemo
//
//  Created by Stanley on 2020/4/20.
//  Copyright © 2020 Stanley. All rights reserved.
//

#import "ShareHelper.h"
#import <FBSDKShareKit/FBSDKShareKit.h>

@interface ShareHelper ()<FBSDKSharingDelegate>

@property(strong, nonatomic) FlutterResult result;
@property(strong, nonatomic) ShareModel *facebookModel;
@property(assign, nonatomic) BOOL didComplete;

@end

@implementation ShareHelper

static NSMutableSet<ShareHelper *> *activeHelpers;

+ (void)initialize
{
    if (self == [ShareHelper class]) {
        activeHelpers = [NSMutableSet set];
    }
}

- (void)shareToPlatformType:(NSString *)platformType withContent:(ShareModel *)model  result:(FlutterResult)result
 {
     self.result = result;
     [self retainForActiveShare];
     dispatch_async(dispatch_get_main_queue(), ^{
         if([@"facebook" isEqualToString:platformType]){
            [self shareToFacebook:model];
         } else {
            [self shareToLine:model];
         }
     });
}

- (void)shareToFacebook:(ShareModel *)model{
    self.facebookModel = model;
    UIViewController *root = [self currentPresenter];
    if (root == nil) {
        [self completeWithState:1 msg:@"無可用頁面"];
        return;
    }

    id<FBSDKSharingContent> content = nil;
    if(model.url.length > 0){
        FBSDKShareLinkContent *linkContent = [[FBSDKShareLinkContent alloc] init];
        linkContent.contentURL = [NSURL URLWithString:model.url];
        content = linkContent;
    } else if(model.image != nil){
        FBSDKSharePhotoContent *photoContent = [[FBSDKSharePhotoContent alloc] init];
        FBSDKSharePhoto *photo = [[FBSDKSharePhoto alloc] initWithImage:model.image isUserGenerated:YES];
        photoContent.photos = @[photo];
        content = photoContent;
    }

    if (content == nil) {
        [self completeWithState:1 msg:@"分享內容不能為空"];
        return;
    }

    if ([self tryShowFacebookDialogWithContent:content
                                          root:root
                                          mode:FBSDKShareDialogModeNative
                                      modeName:@"Native"]) {
        [self fallbackToFacebookWebIfNativeDidNotOpenWithContent:content root:root model:model];
        return;
    }
    if ([self tryShowFacebookDialogWithContent:content
                                          root:root
                                          mode:FBSDKShareDialogModeBrowser
                                      modeName:@"Browser"]) {
        return;
    }
    if ([self tryShowFacebookDialogWithContent:content
                                          root:root
                                          mode:FBSDKShareDialogModeWeb
                                      modeName:@"Web"]) {
        return;
    }

    if ([self openFacebookWebShareWithModel:model]) {
        return;
    }
    [self completeWithState:1 msg:@"無法打開 Facebook 分享"];
}

- (BOOL)tryShowFacebookDialogWithContent:(id<FBSDKSharingContent>)content
                                    root:(UIViewController *)root
                                    mode:(FBSDKShareDialogMode)mode
                                modeName:(NSString *)modeName
{
    FBSDKShareDialog *dialog = [[FBSDKShareDialog alloc] initWithViewController:root
                                                                         content:content
                                                                        delegate:self];
    dialog.mode = mode;
    NSError *validationError = nil;
    if (![dialog validateWithError:&validationError]) {
        return NO;
    }

    if (!dialog.canShow) {
        return NO;
    }

    BOOL showResult = [dialog show];
    return showResult;
}

- (void)fallbackToFacebookWebIfNativeDidNotOpenWithContent:(id<FBSDKSharingContent>)content
                                                       root:(UIViewController *)root
                                                      model:(ShareModel *)model
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIApplicationState state = [UIApplication sharedApplication].applicationState;
        if (self.didComplete || state != UIApplicationStateActive) {
            return;
        }
        if ([self tryShowFacebookDialogWithContent:content
                                              root:root
                                              mode:FBSDKShareDialogModeBrowser
                                          modeName:@"Browser"]) {
            return;
        }
        if ([self tryShowFacebookDialogWithContent:content
                                              root:root
                                              mode:FBSDKShareDialogModeWeb
                                          modeName:@"Web"]) {
            return;
        }
        if ([self openFacebookWebShareWithModel:model]) {
            return;
        }
        [self completeWithState:1 msg:@"無法打開 Facebook 分享"];
    });
}

- (void)shareToLine:(ShareModel *)model{
    NSURL *lineScheme = [NSURL URLWithString:@"line://"];
    UIApplication *application = [UIApplication sharedApplication];
    if([application canOpenURL:lineScheme]){
        NSString *url = @"line://msg";
        if(model.text.length > 0){
            NSString *encodedText = [self percentEncodeText:model.text];
            url = [NSString stringWithFormat:@"%@/text/%@",url,encodedText ?: model.text];
        } else if (model.image != nil) {
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            [pasteboard setData:UIImageJPEGRepresentation(model.image , 1.0) forPasteboardType:@"public.jpeg"];
            url = [NSString stringWithFormat:@"%@/image/%@",url,pasteboard.name];
        } else {
            [self completeWithState:1 msg:@"分享內容不能為空"];
            return;
        }

        NSURL *targetURL = [NSURL URLWithString:url];
        if (targetURL == nil) {
            [self completeWithState:1 msg:@"分享內容無效"];
            return;
        }

        if (@available(iOS 10.0, *)) {
            [application openURL:targetURL options:@{} completionHandler:^(BOOL success) {
                [self completeWithState:(success ? 0 : 1) msg:(success ? @"" : @"分享啟動失敗")];
            }];
        } else {
            BOOL success = [application openURL:targetURL];
            [self completeWithState:(success ? 0 : 1) msg:(success ? @"" : @"分享啟動失敗")];
        }
    } else {
        if (![self openLineWebShareWithModel:model]) {
            [self completeWithState:1 msg:@"未安裝"];
        }
    }
}

- (NSString *)percentEncodeText:(NSString *)text
{
    NSMutableCharacterSet *allowedCharacters = [NSMutableCharacterSet alphanumericCharacterSet];
    [allowedCharacters addCharactersInString:@"-._~"];
    return [text stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
}

- (BOOL)openFacebookWebShareWithModel:(ShareModel *)model
{
    if (model.url.length == 0) {
        return NO;
    }
    NSURLComponents *components = [NSURLComponents componentsWithString:@"https://www.facebook.com/sharer/sharer.php"];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"u" value:model.url],
    ];
    NSURL *targetURL = components.URL;
    return [self openWebFallbackURL:targetURL platformName:@"facebook"];
}

- (BOOL)openLineWebShareWithModel:(ShareModel *)model
{
    if (model.text.length == 0) {
        return NO;
    }
    NSURLComponents *components = [NSURLComponents componentsWithString:@"https://line.me/R/share"];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"text" value:model.text],
    ];
    NSURL *targetURL = components.URL;
    return [self openWebFallbackURL:targetURL platformName:@"line"];
}

- (BOOL)openWebFallbackURL:(NSURL *)targetURL platformName:(NSString *)platformName
{
    if (targetURL == nil) {
        return NO;
    }
    UIApplication *application = [UIApplication sharedApplication];
    if (@available(iOS 10.0, *)) {
        [application openURL:targetURL options:@{} completionHandler:^(BOOL success) {
            [self completeWithState:(success ? 0 : 1) msg:(success ? @"" : @"分享啟動失敗")];
        }];
    } else {
        BOOL success = [application openURL:targetURL];
        [self completeWithState:(success ? 0 : 1) msg:(success ? @"" : @"分享啟動失敗")];
    }
    return YES;
}

- (void)sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary<NSString *, id> *)results{
    [self completeWithState:0 msg:@""];
}

- (void)sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error {
    NSString *message = error.localizedDescription.length > 0 ? error.localizedDescription : @"分享失敗";
    if ([self openFacebookWebShareWithModel:self.facebookModel]) {
        return;
    }
    [self completeWithState:1 msg:message];
}

- (void)sharerDidCancel:(id<FBSDKSharing>)sharer {
    [self completeWithState:2 msg:@"用戶取消"];
}

- (void)retainForActiveShare
{
    @synchronized ([ShareHelper class]) {
        [activeHelpers addObject:self];
    }
}

- (void)releaseActiveShare
{
    @synchronized ([ShareHelper class]) {
        [activeHelpers removeObject:self];
    }
}

- (void)completeWithState:(NSInteger)state msg:(NSString *)msg
{
    if (self.didComplete) {
        return;
    }
    self.didComplete = YES;

    FlutterResult callback = self.result;
    self.result = nil;
    self.facebookModel = nil;
    if (callback != nil) {
        callback(@{@"state": @(state), @"msg": msg ?: @""});
    }
    [self releaseActiveShare];
}

- (UIViewController *)currentPresenter
{
    UIWindow *window = [self activeWindow];
    return [self topViewControllerFrom:window.rootViewController];
}

- (UIWindow *)activeWindow
{
    UIApplication *application = [UIApplication sharedApplication];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState != UISceneActivationStateForegroundActive) {
                continue;
            }
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }
            if (windowScene.windows.count > 0) {
                return windowScene.windows.firstObject;
            }
        }
    }
    if (application.keyWindow != nil) {
        return application.keyWindow;
    }
    if (application.windows.count > 0) {
        return application.windows.firstObject;
    }
    return nil;
}

- (UIViewController *)topViewControllerFrom:(UIViewController *)controller
{
    if (controller == nil) {
        return nil;
    }
    if ([controller isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)controller;
        return [self topViewControllerFrom:navigationController.visibleViewController];
    }
    if ([controller isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabBarController = (UITabBarController *)controller;
        return [self topViewControllerFrom:tabBarController.selectedViewController];
    }
    if (controller.presentedViewController != nil) {
        return [self topViewControllerFrom:controller.presentedViewController];
    }
    return controller;
}


@end
