#import "FluttersharePlugin.h"
#import "Share/ShareHelper.h"
#import "Share/ShareModel.h"
//#if __has_include(<fluttershare/fluttershare-Swift.h>)
//#import <fluttershare/fluttershare-Swift.h>
//#else
//// Support project import fallback if the generated compatibility header
//// is not copied when this plugin is created as a library.
//// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
//#import "fluttershare-Swift.h"
//#endif

@implementation FluttersharePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  //[SwiftFluttersharePlugin registerWithRegistrar:registrar];
    FlutterMethodChannel* channel = [FlutterMethodChannel
        methodChannelWithName:@"fluttershare"
              binaryMessenger:[registrar messenger]];
    FluttersharePlugin* instance = [[FluttersharePlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  NSLog(@"[fluttershare][iOS] method=%@ arguments=%@", call.method, call.arguments);
  if ([@"getPlatformVersion" isEqualToString:call.method]) {
      result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
  } else if ([@"share" isEqualToString:call.method]) {
      NSDictionary *arguments = [call.arguments isKindOfClass:[NSDictionary class]] ? call.arguments : @{};
      ShareModel * model = [[ShareModel alloc] initWithParams:arguments];
      NSString * platform = arguments[@"platform"];
      ShareHelper *helper = [[ShareHelper alloc] init];
      NSLog(@"[fluttershare][iOS] share platform=%@ modelUrl=%@ textLength=%lu image=%@",
            platform,
            model.url,
            (unsigned long)model.text.length,
            model.image == nil ? @"nil" : @"not_nil");
      if([@"SharePlatform.Facebook" isEqualToString:platform]){
          NSLog(@"[fluttershare][iOS] dispatch facebook share");
          [helper shareToPlatformType:@"facebook" withContent:model result:result];
      } else {
          NSLog(@"[fluttershare][iOS] dispatch line share");
          [helper shareToPlatformType:@"line" withContent:model result:result];
      }
  } else {
      result(FlutterMethodNotImplemented);
  }
}

@end
