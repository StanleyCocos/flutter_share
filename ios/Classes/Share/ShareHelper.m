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
     NSLog(@"[fluttershare][iOS] shareToPlatformType=%@ url=%@ textLength=%lu image=%@",
           platformType,
           model.url,
           (unsigned long)model.text.length,
           model.image == nil ? @"nil" : @"not_nil");
     dispatch_async(dispatch_get_main_queue(), ^{
         NSLog(@"[fluttershare][iOS] share on main thread=%@", [NSThread isMainThread] ? @"YES" : @"NO");
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
    NSLog(@"[fluttershare][iOS] facebook presenter=%@ url=%@ image=%@",
          root,
          model.url,
          model.image == nil ? @"nil" : @"not_nil");
    if (root == nil) {
        [self completeWithState:1 msg:@"無可用頁面"];
        return;
    }

    id<FBSDKSharingContent> content = nil;
    if(model.url.length > 0){
        FBSDKShareLinkContent *linkContent = [[FBSDKShareLinkContent alloc] init];
        linkContent.contentURL = [NSURL URLWithString:model.url];
        content = linkContent;
        NSLog(@"[fluttershare][iOS] facebook content linkURL=%@", linkContent.contentURL);
    } else if(model.image != nil){
        FBSDKSharePhotoContent *photoContent = [[FBSDKSharePhotoContent alloc] init];
        FBSDKSharePhoto *photo = [[FBSDKSharePhoto alloc] initWithImage:model.image isUserGenerated:YES];
        photoContent.photos = @[photo];
        content = photoContent;
        NSLog(@"[fluttershare][iOS] facebook content photo");
    }

    if (content == nil) {
        NSLog(@"[fluttershare][iOS] facebook content nil");
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

    NSLog(@"[fluttershare][iOS] facebook all modes unavailable");
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
        NSLog(@"[fluttershare][iOS] facebook %@ validate failed error=%@", modeName, validationError);
        return NO;
    }
    NSLog(@"[fluttershare][iOS] facebook %@ validate success", modeName);

    if (!dialog.canShow) {
        NSLog(@"[fluttershare][iOS] facebook %@ canShow=NO", modeName);
        return NO;
    }
    NSLog(@"[fluttershare][iOS] facebook %@ canShow=YES", modeName);

    BOOL showResult = [dialog show];
    NSLog(@"[fluttershare][iOS] facebook %@ show result=%@", modeName, showResult ? @"YES" : @"NO");
    return showResult;
}

- (void)fallbackToFacebookWebIfNativeDidNotOpenWithContent:(id<FBSDKSharingContent>)content
                                                       root:(UIViewController *)root
                                                      model:(ShareModel *)model
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIApplicationState state = [UIApplication sharedApplication].applicationState;
        NSLog(@"[fluttershare][iOS] facebook Native fallback check didComplete=%@ appState=%ld",
              self.didComplete ? @"YES" : @"NO",
              (long)state);
        if (self.didComplete || state != UIApplicationStateActive) {
            return;
        }
        NSLog(@"[fluttershare][iOS] facebook Native did not leave app, fallback Browser/Web");
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
    NSLog(@"[fluttershare][iOS] line canOpen=%@", [application canOpenURL:lineScheme] ? @"YES" : @"NO");
    if([application canOpenURL:lineScheme]){
        NSString *url = @"line://msg";
        if(model.url.length > 0){
            NSString *encodedURL = [model.url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
            url = [NSString stringWithFormat:@"%@/text/%@",url,encodedURL ?: model.url];
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
                NSLog(@"[fluttershare][iOS] line openURL success=%@", success ? @"YES" : @"NO");
                [self completeWithState:(success ? 0 : 1) msg:(success ? @"" : @"分享啟動失敗")];
            }];
        } else {
            BOOL success = [application openURL:targetURL];
            NSLog(@"[fluttershare][iOS] line openURL legacy success=%@", success ? @"YES" : @"NO");
            [self completeWithState:(success ? 0 : 1) msg:(success ? @"" : @"分享啟動失敗")];
        }
    } else {
        NSLog(@"[fluttershare][iOS] line app not installed, fallback web");
        if (![self openLineWebShareWithModel:model]) {
            [self completeWithState:1 msg:@"未安裝"];
        }
    }
}

- (BOOL)openFacebookWebShareWithModel:(ShareModel *)model
{
    if (model.url.length == 0) {
        NSLog(@"[fluttershare][iOS] facebook web fallback missing url");
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
    if (model.url.length == 0) {
        NSLog(@"[fluttershare][iOS] line web fallback missing url");
        return NO;
    }
    NSURLComponents *components = [NSURLComponents componentsWithString:@"https://social-plugins.line.me/lineit/share"];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"url" value:model.url],
    ];
    NSURL *targetURL = components.URL;
    return [self openWebFallbackURL:targetURL platformName:@"line"];
}

- (BOOL)openWebFallbackURL:(NSURL *)targetURL platformName:(NSString *)platformName
{
    if (targetURL == nil) {
        NSLog(@"[fluttershare][iOS] %@ web fallback invalid url", platformName);
        return NO;
    }
    UIApplication *application = [UIApplication sharedApplication];
    NSLog(@"[fluttershare][iOS] %@ web fallback open url=%@", platformName, targetURL);
    if (@available(iOS 10.0, *)) {
        [application openURL:targetURL options:@{} completionHandler:^(BOOL success) {
            NSLog(@"[fluttershare][iOS] %@ web fallback success=%@", platformName, success ? @"YES" : @"NO");
            [self completeWithState:(success ? 0 : 1) msg:(success ? @"" : @"分享啟動失敗")];
        }];
    } else {
        BOOL success = [application openURL:targetURL];
        NSLog(@"[fluttershare][iOS] %@ web fallback legacy success=%@", platformName, success ? @"YES" : @"NO");
        [self completeWithState:(success ? 0 : 1) msg:(success ? @"" : @"分享啟動失敗")];
    }
    return YES;
}

- (void)sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary<NSString *, id> *)results{
    NSLog(@"[fluttershare][iOS] facebook delegate complete results=%@", results);
    [self completeWithState:0 msg:@""];
}

- (void)sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error {
    NSString *message = error.localizedDescription.length > 0 ? error.localizedDescription : @"分享失敗";
    NSLog(@"[fluttershare][iOS] facebook delegate fail error=%@", error);
    if ([self openFacebookWebShareWithModel:self.facebookModel]) {
        return;
    }
    [self completeWithState:1 msg:message];
}

- (void)sharerDidCancel:(id<FBSDKSharing>)sharer {
    NSLog(@"[fluttershare][iOS] facebook delegate cancel");
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
        NSLog(@"[fluttershare][iOS] complete ignored state=%ld msg=%@", (long)state, msg);
        return;
    }
    self.didComplete = YES;

    FlutterResult callback = self.result;
    self.result = nil;
    self.facebookModel = nil;
    NSLog(@"[fluttershare][iOS] complete state=%ld msg=%@", (long)state, msg);
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
            NSLog(@"[fluttershare][iOS] scene=%@ activationState=%ld",
                  scene,
                  (long)scene.activationState);
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState != UISceneActivationStateForegroundActive) {
                continue;
            }
            for (UIWindow *window in windowScene.windows) {
                NSLog(@"[fluttershare][iOS] window=%@ isKey=%@", window, window.isKeyWindow ? @"YES" : @"NO");
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
