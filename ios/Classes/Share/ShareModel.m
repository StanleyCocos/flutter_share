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
    
    NSString * image = params[@"image"];
    NSString * text = params[@"text"];
    NSLog(@"[fluttershare][iOS] ShareModel init text=%@ textLength=%lu imagePath=%@",
          text,
          (unsigned long)text.length,
          image);
    
    if([text hasPrefix:@"http"]){
        self.url = text;
    } else {
        self.text = text;
    }
    
    if([image hasPrefix:@"http"]){
        self.image = [self downloadImageResouce:image];
    } else {
        self.image = [UIImage imageWithContentsOfFile: image];
    }
    NSLog(@"[fluttershare][iOS] ShareModel resolved url=%@ textLength=%lu image=%@",
          self.url,
          (unsigned long)self.text.length,
          self.image == nil ? @"nil" : @"not_nil");

}

-(UIImage *)downloadImageResouce:(NSString *)url{
    NSString * loadUrl = url;
    if([loadUrl hasSuffix:@".webp"]){
       loadUrl = [loadUrl stringByReplacingOccurrencesOfString:@".webp" withString:@".png"];
    }
    NSLog(@"[fluttershare][iOS] download image url=%@", loadUrl);
    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString: loadUrl]];
    UIImage *downloadedImage = [UIImage imageWithData:data];
    NSLog(@"[fluttershare][iOS] download image result=%@", downloadedImage == nil ? @"nil" : @"not_nil");
    return downloadedImage;
}

@end
