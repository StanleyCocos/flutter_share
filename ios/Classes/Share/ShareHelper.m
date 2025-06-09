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

@end

@implementation ShareHelper

- (void)shareToPlatformType:(NSString *)platformType withContent:(ShareModel *)model  result:(FlutterResult)result
 {
     self.result = result;
     if([@"facebook" isEqualToString:platformType]){
        [self shareToFacebook:model];

    } else {
        [self shareToLine:model];
    }
}

- (void)shareToFacebook:(ShareModel *)model{
    
    UIViewController * root = [[UIApplication sharedApplication] keyWindow].rootViewController;
    
    if(model.url.length > 0){
        FBSDKShareLinkContent *content = [[FBSDKShareLinkContent alloc] init];
        content.contentURL = [NSURL URLWithString: model.url];
        [FBSDKShareDialog showFromViewController: root withContent:content delegate: self];
    } else if(model.image != nil){
        FBSDKSharePhotoContent *content = [[FBSDKSharePhotoContent alloc] init];
        FBSDKSharePhoto *photo = [[FBSDKSharePhoto alloc] initWithImage:model.image isUserGenerated:YES];
        photo.isUserGenerated = YES;
        content.photos = @[photo];
        [FBSDKShareDialog showFromViewController: root withContent:content delegate: self];
    }
}

- (void)shareToLine:(ShareModel *)model{
    
    if([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"line://"]]){
        NSString * url = @"line://msg";
        if(model.url.length > 0){
            url = [NSString stringWithFormat:@"%@/text/%@",url,model.url];
        }else {
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            [pasteboard setData:UIImageJPEGRepresentation(model.image , 1.0) forPasteboardType:@"public.jpeg"];
            url = [NSString stringWithFormat:@"%@/image/%@",url,pasteboard.name];
        }
        self.result(@{@"state": @0, @"msg": @""});
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString: url]];
    } else {
        self.result(@{@"state": @1, @"msg": @"未安裝"});
    }
}

- (void)sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary<NSString *, id> *)results{
    self.result(@{@"state": @0, @"msg": @""});
}

- (void)sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error {
    self.result(@{@"state": @1, @"msg": @"未安裝"});
}

- (void)sharerDidCancel:(id<FBSDKSharing>)sharer {
    self.result(@{@"state": @2, @"msg": @"用戶取消"});
}


@end
