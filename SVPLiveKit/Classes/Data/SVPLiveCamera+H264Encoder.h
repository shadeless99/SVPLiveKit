//
//  SVPLiveCamera+H264Encoder.h
//  DemoLiveStreaming
//
//  Created by yongqingguo on 16/4/29.
//  Copyright © 2016年 gyq. All rights reserved.
//

#import "SVPLiveCamera.h"
#import "H264HwEncoderImpl.h"

/**
 *  视频H264编码
 */
@interface SVPLiveCamera (H264Encoder)<H264HwEncoderImplDelegate>

/**
 *  H264硬编码器
 */
@property(nonatomic,strong) H264HwEncoderImpl *h264Encoder;

/**
 *  初始化编码器
 */
- (void)initH264EncoderWithBitrate:(NSInteger)bitrate;

/**
 *  H264编码
 *
 *  @param sampleBuffer 摄像头采集的每一帧数据
 *  @param watermasks 水印图片，传空则不添加水印
 *
 *  @return 返回编码后得到的UIImage对象
 */
- (UIImage *)encodeH264:(CMSampleBufferRef)sampleBuffer watermasks:(NSArray *)watermasks;

@end
