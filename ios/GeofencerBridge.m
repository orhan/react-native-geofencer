//
//  GeofencerBridge.m
//

#import "RCTBridgeModule.h"

@interface RCT_EXTERN_MODULE(Geofencer, NSObject)

RCT_EXTERN_METHOD(intialize:(RCTResponseSenderBlock)success error: (RCTResponseSenderBlock)error)

RCT_EXTERN_METHOD(addOrUpdate:(NSArray *)geofences success: (RCTResponseSenderBlock)success error: (RCTResponseSenderBlock)error)

RCT_EXTERN_METHOD(remove:(NSArray *)ids success: (RCTResponseSenderBlock)success error: (RCTResponseSenderBlock)error)

RCT_EXTERN_METHOD(removeAll:(RCTResponseSenderBlock)success error: (RCTResponseSenderBlock)error)

RCT_EXTERN_METHOD(getWatched:(RCTResponseSenderBlock)success error: (RCTResponseSenderBlock)error)

@end