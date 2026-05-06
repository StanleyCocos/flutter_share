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
        FBSDKSharePhoto *photo = [[FBSDKSharePhoto alloc] init];
        photo.image = model.image;
        photo.userGenerated = YES;
        photoContent.photos = @[photo];
        content = photoContent;
    }

    if (content == nil) {
        [self completeWithState:1 msg:@"分享內容不能為空"];
        return;
    }

    FBSDKShareDialog *dialog = [[FBSDKShareDialog alloc] initWithViewController:root
                                                                         content:content
                                                                        delegate:self];
    NSError *validationError = nil;
    if (![dialog validateWithError:&validationError]) {
        [self completeWithState:1 msg:validationError.localizedDescription ?: @"分享內容無效"];
        return;
    }

    if (!dialog.canShow) {
        [self completeWithState:1 msg:@"無法打開 Facebook 分享"];
        return;
    }

    if (![dialog show]) {
        [self completeWithState:1 msg:@"分享啟動失敗"];
    }
}

- (void)shareToLine:(ShareModel *)model{
    NSURL *lineScheme = [NSURL URLWithString:@"line://"];
    UIApplication *application = [UIApplication sharedApplication];
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
                [self completeWithState:(success ? 0 : 1) msg:(success ? @"" : @"分享啟動失敗")];
            }];
        } else {
            BOOL success = [application openURL:targetURL];
            [self completeWithState:(success ? 0 : 1) msg:(success ? @"" : @"分享啟動失敗")];
        }
    } else {
        [self completeWithState:1 msg:@"未安裝"];
    }
}

- (void)sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary<NSString *, id> *)results{
    [self completeWithState:0 msg:@""];
}

- (void)sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error {
    NSString *message = error.localizedDescription.length > 0 ? error.localizedDescription : @"分享失敗";
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
