//
//  SVPLiveConfiguration.h
//  DemoLiveStreaming
//
//  Created by yongqingguo on 16/4/29.
//  Copyright © 2016年 gyq. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define SUPPORT_H264_ENCODER 1 // 是否支持视频H264编码
#define SUPPORT_AAC_ENCODER  1 // 是否支持音频AAC编码
#define SUPPORT_WATERMASKS   1 // 是否支持图片水印

#define FRAME_RATE_HIGH   20

#define BIT_RATE_HIGH        (700*1024) // bps

#define BIT_RATE_MAX  (BIT_RATE_HIGH*1.2)

// 16:9
#define VIDEO_WIDTH_0             800
#define VIDEO_HEIGHT_0            464

// 4:3
#define VIDEO_WIDTH_1             640
#define VIDEO_HEIGHT_1            480

#define TIME_SCALE              1000

#define FRAME_DURATION          (1000/FRAME_RATE_HIGH)

#define DEFAULT_FRAME_RATE          FRAME_RATE_HIGH
#define DEFAULT_BIT_RATE            BIT_RATE_HIGH

extern NSString *const UPLOAD_INFO_TIMESCALE;
extern NSString *const UPLOAD_INFO_BITRATE;
extern NSString *const UPLOAD_VIDEO_INFO_WIDTH;
extern NSString *const UPLOAD_VIDEO_INFO_HEIGHT;
extern NSString *const UPLOAD_VIDEO_INFO_FRAME_RATE;
extern NSString *const UPLOAD_AUDIO_INFO_CHANNEL_COUNT;
extern NSString *const UPLOAD_AUDIO_INFO_SAMPLE_SIZE;
extern NSString *const UPLOAD_AUDIO_INFO_SAMPLE_RATE;
extern NSString *const UPLOAD_SAMPLE_INFO_STREAM_TYPE;
extern NSString *const UPLOAD_SAMPLE_INFO_IS_KEY_FRAME;
extern NSString *const UPLOAD_SAMPLE_INFO_TIME;
extern NSString *const UPLOAD_SAMPLE_INFO_CTS_DELTA;

/**
 *  直播相关参数配置
 */
@interface SVPLiveConfiguration : NSObject

/**
 *  视频/音频文件存储路径，默认路径为Documents/live/
 */
@property(nonatomic,copy) NSString *outputPath;
@property(nonatomic,copy) NSString *localDirectory;
@property(nonatomic,copy) NSString *localSavedFileFullPath;
@property(nonatomic,assign,readonly) CGRect watermarkFrame;
@property(nonatomic,copy) NSString *watermarkStyle;

/**
 *  编码码率
 */
@property(nonatomic,assign) NSInteger bitrate;

/**
 *  屏幕分辨率比例，16：9 或 4：3
 */
@property(nonatomic,assign) NSInteger screenRatio;

@end
