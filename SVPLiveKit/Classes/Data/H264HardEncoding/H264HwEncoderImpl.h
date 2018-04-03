//
//  H264HwEncoderImpl.h
//  h264v1
//
//  Created by Ganvir, Manish on 3/31/15.
//  Copyright (c) 2015 Ganvir, Manish. All rights reserved.
//  H264硬编码，对VideoToolbox进行封装，提供Objective-C接口，适用于iOS8及以上版本

#import <Foundation/Foundation.h>
@import AVFoundation;

@protocol H264HwEncoderImplDelegate <NSObject>

- (void)gotSpsPps:(NSData *)sps pps:(NSData *)pps;
- (void)gotEncodedData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame;

@end

@interface H264HwEncoderImpl : NSObject 

- (void)initWithConfiguration;
- (void)initEncode:(int)width height:(int)height bitrate:(NSInteger)bitrate;
- (void)encode:(CMSampleBufferRef)sampleBuffer;
- (void)encodePixel:(CVPixelBufferRef)pixelBuffer;
- (void)End;


@property (weak, nonatomic) NSString *error;
@property (weak, nonatomic) id<H264HwEncoderImplDelegate> delegate;

@end
