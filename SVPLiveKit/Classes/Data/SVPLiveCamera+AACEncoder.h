//
//  SVPLiveCamera+AACEncoder.h
//  DemoLiveStreaming
//
//  Created by yongqingguo on 16/4/29.
//  Copyright © 2016年 gyq. All rights reserved.
//

#import "SVPLiveCamera.h"

@protocol SVPAACEncoderDelegate <NSObject>

@optional

/**
 *  拿到编码后的数据
 *
 *  @param data 编码后的一帧数据
 */
- (void)gotEncodedData:(NSData *)data;

@end

@interface SVPAACEncoder : NSObject

/**
 *  处理编码后每一帧数据的委托
 */
@property(nonatomic,assign) id<SVPAACEncoderDelegate> delegate;

/**
 *  AAC音频编码
 *
 *  @param sampleBuffer 每一帧数据
 */
- (BOOL)encodeAAC:(CMSampleBufferRef)sampleBuffer;

@end

/**
 *  音频AAC编码
 */
@interface SVPLiveCamera (AACEncoder)<SVPAACEncoderDelegate>

/**
 *  AAC编码器
 */
@property(nonatomic,strong) SVPAACEncoder *aacEncoder;
/**
 *  音频数据头
 */
@property(nonatomic,strong) NSData *audioHeader;

/**
 *  初始化编码器
 */
- (void)initAACEncoder;

/**
 *  编码PCM成AAC
 *
 *  @param sampleBuffer 音频帧数据
 */
- (BOOL)encodeAAC:(CMSampleBufferRef)sampleBuffer;

@end
