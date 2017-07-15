//
//  GeofencerBridge.m
//

#import "RCTBridgeModule.h"

@interface RCT_EXTERN_MODULE(Geofencer, NSObject)

RCT_EXTERN_METHOD(initialize:(RCTResponseSenderBlock)success failed: (RCTResponseSenderBlock)failed)

RCT_EXTERN_METHOD(addOrUpdate:(NSArray *)geofences success: (RCTResponseSenderBlock)success failed: (RCTResponseSenderBlock)failed)

RCT_EXTERN_METHOD(remove:(NSArray *)ids success: (RCTResponseSenderBlock)success failed: (RCTResponseSenderBlock)failed)

RCT_EXTERN_METHOD(removeAll:(RCTResponseSenderBlock)success failed: (RCTResponseSenderBlock)failed)

RCT_EXTERN_METHOD(getWatched:(RCTResponseSenderBlock)success failed: (RCTResponseSenderBlock)failed)

@end