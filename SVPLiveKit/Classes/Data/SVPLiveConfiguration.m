//
//  SVPLiveConfiguration.m
//  DemoLiveStreaming
//
//  Created by yongqingguo on 16/4/29.
//  Copyright © 2016年 gyq. All rights reserved.
//

#import "SVPLiveConfiguration.h"

NSString *const UPLOAD_INFO_TIMESCALE = @"timeScale";
NSString *const UPLOAD_INFO_BITRATE = @"bitRate";
NSString *const UPLOAD_VIDEO_INFO_WIDTH = @"width";
NSString *const UPLOAD_VIDEO_INFO_HEIGHT = @"height";
NSString *const UPLOAD_VIDEO_INFO_FRAME_RATE = @"frameRate";
NSString *const UPLOAD_AUDIO_INFO_CHANNEL_COUNT = @"channelCount";
NSString *const UPLOAD_AUDIO_INFO_SAMPLE_SIZE = @"sampleSize";
NSString *const UPLOAD_AUDIO_INFO_SAMPLE_RATE = @"sampleRate";
NSString *const UPLOAD_SAMPLE_INFO_STREAM_TYPE = @"streamType";
NSString *const UPLOAD_SAMPLE_INFO_IS_KEY_FRAME = @"keyFrame";
NSString *const UPLOAD_SAMPLE_INFO_TIME = @"time";
NSString *const UPLOAD_SAMPLE_INFO_CTS_DELTA = @"ctsDelta";

#define SVPLiveFrameWidth [UIScreen mainScreen].bounds.size.width
#define SVPLiveFrameHeight [UIScreen mainScreen].bounds.size.height
#define LANDSCAPE_SCREEN_WIDTH MAX(SVPLiveFrameWidth, SVPLiveFrameHeight)
#define LANDSCAPE_SCREEN_HEIGHT MIN(SVPLiveFrameWidth, SVPLiveFrameHeight)
/** 视频/音频文件默认存储路径documents/live/ */
#define DEFAULT_SAVED_TEMP_FILE_PATH [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"Live"]
/** 水印默认四种位置 */
// 左上角logo
#define LOGO1_WATERMARK_FRAME CGRectMake(40 / 1334.f * LANDSCAPE_SCREEN_WIDTH,14 / 750.f * LANDSCAPE_SCREEN_HEIGHT,137 / 1334.f * LANDSCAPE_SCREEN_WIDTH,65 / 750.f * LANDSCAPE_SCREEN_HEIGHT)
// 右上角logo
#define LOGO2_WATERMARK_FRAME CGRectMake(1124 / 1334.f * LANDSCAPE_SCREEN_WIDTH,6 / 750.f * LANDSCAPE_SCREEN_HEIGHT,170 / 1334.f * LANDSCAPE_SCREEN_WIDTH,81 / 750.f * LANDSCAPE_SCREEN_HEIGHT)
// 水平新闻标题
#define HORIZONTAL_WATERMARK_FRAME CGRectMake(75 / 1334.f * LANDSCAPE_SCREEN_WIDTH,548 / 750.f * LANDSCAPE_SCREEN_HEIGHT,850 / 1334.f * LANDSCAPE_SCREEN_WIDTH,152 / 750.f * LANDSCAPE_SCREEN_HEIGHT)
// 垂直新闻标题
#define VERTICAL_WATERMARK_FRAME CGRectMake(1163 / 1334.f * LANDSCAPE_SCREEN_WIDTH,93 / 750.f * LANDSCAPE_SCREEN_HEIGHT,95 / 1334.f * LANDSCAPE_SCREEN_WIDTH,452 / 750.f * LANDSCAPE_SCREEN_HEIGHT)

@interface SVPLiveConfiguration()

@property(nonatomic,assign,readwrite) CGRect watermarkFrame;

@end

@implementation SVPLiveConfiguration

- (NSString *)localDirectory {
    if (!_localDirectory) {
        _localDirectory = DEFAULT_SAVED_TEMP_FILE_PATH;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL fileExists = [fileManager fileExistsAtPath:_localDirectory];
        if (!fileExists) {
            [fileManager createDirectoryAtPath:_localDirectory  withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    return _localDirectory;
}

- (NSString *)watermarkStyle {
    if (!_watermarkStyle || (_watermarkStyle && ![_watermarkStyle isEqualToString:@"h"] && ![_watermarkStyle isEqualToString:@"v"] && ![_watermarkStyle isEqualToString:@"l1"] && ![_watermarkStyle isEqualToString:@"l2"])) {
        _watermarkStyle = @"";
    }
    return _watermarkStyle;
}

- (CGRect)watermarkFrame {
    if ([self.watermarkStyle isEqualToString:@"h"]) {
        return HORIZONTAL_WATERMARK_FRAME;
    } else if ([self.watermarkStyle isEqualToString:@"v"]) {
        return VERTICAL_WATERMARK_FRAME;
    } else if ([self.watermarkStyle isEqualToString:@"l1"]) {
        return LOGO1_WATERMARK_FRAME;
    } else if ([self.watermarkStyle isEqualToString:@"l2"]) {
        return LOGO2_WATERMARK_FRAME;
    }
    return CGRectZero;
}

@end
