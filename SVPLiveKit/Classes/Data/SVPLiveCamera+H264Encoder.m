//
//  SVPLiveCamera+H264Encoder.m
//  DemoLiveStreaming
//
//  Created by yongqingguo on 16/4/29.
//  Copyright © 2016年 gyq. All rights reserved.
//

#import "SVPLiveCamera+H264Encoder.h"
#import <objc/runtime.h>
#import "UIImage+Resize.h"

static char *h264EncoderKey = "h264EncoderKey";

@implementation SVPLiveCamera (H264Encoder)

#pragma mark - Public

- (H264HwEncoderImpl *)h264Encoder {
    return objc_getAssociatedObject(self, h264EncoderKey);
}

- (void)setH264Encoder:(H264HwEncoderImpl *)h264Encoder {
    objc_setAssociatedObject(self, h264EncoderKey, h264Encoder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)initH264EncoderWithBitrate:(NSInteger)bitrate {
    self.h264Encoder = [[H264HwEncoderImpl alloc] init];
    [self.h264Encoder initWithConfiguration];
    [self.h264Encoder initEncode:self.screenWidth height:self.screenHeight bitrate:bitrate];
}

- (UIImage *)processCameraOutput:(CMSampleBufferRef)sampleBuffer watermasks:(NSArray *)watermasks {
    return [UIImage watermaskedBuffer:sampleBuffer maskImages:watermasks];
}

- (UIImage *)encodeH264:(CMSampleBufferRef)sampleBuffer watermasks:(NSArray *)watermasks {
    // 修复停止直播后，编码仍然继续造成的内存没法释放的bug
    if (self.isCameraStopped) {
        return nil;
    }
//    if (watermasks && watermasks.count > 0) {
        UIImage *img = [self processCameraOutput:sampleBuffer watermasks:watermasks];
        CVPixelBufferRef pxbuffer = [UIImage pixelBufferRefFromImage:img];
        [self.h264Encoder encodePixel:pxbuffer];
        return img;
//    } else {
//        [self.h264Encoder encode:sampleBuffer];
//        return nil;
//    }
}

#pragma mark -  H264HwEncoderImplDelegate

- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps {
    NSLog(@"gotSpsPps %d %d", (int)[sps length], (int)[pps length]);
    
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; // string literals have implicit trailing '\0'
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    
    [self.h264FileHandler writeData:byteHeader];
    [self.h264FileHandler writeData:sps];
    [self.h264FileHandler writeData:byteHeader];
    [self.h264FileHandler writeData:pps];
    
    NSMutableData *data = [NSMutableData data];
    [data appendData:byteHeader];
    [data appendData:sps];
    [data appendData:byteHeader];
    [data appendData:pps];
    
    if (self.delegate
        && [self.delegate respondsToSelector:@selector(svpLiveCameraDidCaptureSpsPps:upVideoInfo:)]) {
        [self.delegate svpLiveCameraDidCaptureSpsPps:data upVideoInfo:@{UPLOAD_INFO_TIMESCALE:@(TIME_SCALE),
                                                                        UPLOAD_INFO_BITRATE:@(DEFAULT_BIT_RATE),
                                                                        UPLOAD_VIDEO_INFO_WIDTH:@(self.screenWidth),
                                                                        UPLOAD_VIDEO_INFO_HEIGHT:@(self.screenHeight),
                                                                        UPLOAD_VIDEO_INFO_FRAME_RATE:@(DEFAULT_FRAME_RATE)}];
    }
}

- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame {
    NSLog(@"gotEncodedData %d", (int)[data length]);
    
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; // string literals have implicit trailing '\0'
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    
    [self.h264FileHandler writeData:byteHeader];
    [self.h264FileHandler writeData:data];
    
    NSMutableData *da = [NSMutableData data];
    [da appendData:byteHeader];
    [da appendData:data];
    
    long long time = [[NSString stringWithFormat:@"%.f",([[NSDate date] timeIntervalSince1970] - self.originTimestamp) * 1000] longLongValue];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(svpLiveCameraDidCaptureEncodedData:timestamp:isVideo:isKeyframe:)]) {
        [self.delegate svpLiveCameraDidCaptureEncodedData:da timestamp:time isVideo:YES isKeyframe:isKeyFrame];
    }
}

@end
