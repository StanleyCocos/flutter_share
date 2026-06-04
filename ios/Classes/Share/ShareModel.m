//
//  ShareModel.m
//  ShareDemo
//
//  Created by Stanley on 2020/4/20.
//  Copyright © 2020 Stanley. All rights reserved.
//

#import "ShareModel.h"


@implementation ShareModel


- (instancetype)initWithParams:(NSDictionary *)params
{
    self = [super init];
    if (self) {
        [self initParams:params];
    }
    return self;
}

- (void)initParams:(NSDictionary *)params{
    
    id imageValue = params[@"image"];
    id textValue = params[@"text"];
    NSString * image = [imageValue isKindOfClass:[NSString class]] ? imageValue : @"";
    NSString * text = [textValue isKindOfClass:[NSString class]] ? textValue : @"";
    
    self.text = text;
    if([text hasPrefix:@"http"]){
        self.url = text;
    }
    
    if([image hasPrefix:@"http"]){
        self.image = [self downloadImageResouce:image];
    } else if (image.length > 0) {
        self.image = [UIImage imageWithContentsOfFile: image];
    }

}

-(UIImage *)downloadImageResouce:(NSString *)url{
    NSString * loadUrl = url;
    if([loadUrl hasSuffix:@".webp"]){
       loadUrl = [loadUrl stringByReplacingOccurrencesOfString:@".webp" withString:@".png"];
    }
    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString: loadUrl]];
    UIImage *downloadedImage = [UIImage imageWithData:data];
    return downloadedImage;
}

@end
