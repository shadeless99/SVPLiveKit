//
//  SVPLiveUploadEngine.m
//  DemoLiveStreaming
//
//  Created by yongqingguo on 16/3/22.
//  Copyright © 2016年 gyq. All rights reserved.
//

#import "SVPLiveUploadEngine.h"
#import "SVPLive.h"

@implementation SVPUploadInfo

+ (instancetype)sharedInstance {
    static SVPUploadInfo *uploadInfo = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        uploadInfo = [[SVPUploadInfo alloc] init];
    });
    return uploadInfo;
}

@end

@implementation SVPLiveUploadEngine

//streamsdk::StreamUploader *streamUploader = NULL;

- (BOOL)isStringEmpty:(NSString *)string {
    if([string length] == 0) {
        return YES;
    }
    
    if(![[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length]) {
        return YES;
    }
    return NO;
}

- (instancetype)initWithURL:(NSString *)url filePath:(NSString *)filePath {
    self = [super init];
    if (self) {
//        streamUploader = new streamsdk::StreamUploader(streamsdk::StreamUploader::OTE_stream);
//        if (filePath && ![self isStringEmpty:filePath]) {
//            streamUploader->openRtmpUrlBySave(url.UTF8String, filePath.UTF8String);
//        } else {
//            streamUploader->openRtmpUrl(url.UTF8String);
//        }
//        if(![self isStringEmpty:[SVPLive getCacheDuration]]){
//            streamUploader->setParams("cache-duration",[[SVPLive getCacheDuration] UTF8String]);
//            NSLog(@"cache-duration:%@",[SVPLive getCacheDuration]);
//        }
        //streamUploader->openRtmpUrl("rtmp://10.226.64.66/live/ymtest");
    }
    return self;
}

- (void)addVideoStream:(NSDictionary *)upVideoInfo length:(long)len data:(NSData *)data totalSize:(long)totalSize {
//    streamsdk::UpVideoInfo videoInfo;
//    videoInfo.timeScale = [upVideoInfo[UPLOAD_INFO_TIMESCALE] longLongValue];
//    videoInfo.bitRate = [upVideoInfo[UPLOAD_INFO_BITRATE] longLongValue];
//    videoInfo.width = [upVideoInfo[UPLOAD_VIDEO_INFO_WIDTH] longLongValue];
//    videoInfo.height = [upVideoInfo[UPLOAD_VIDEO_INFO_HEIGHT] longLongValue];
//    videoInfo.frameRate = [upVideoInfo[UPLOAD_VIDEO_INFO_FRAME_RATE] longLongValue];
//    streamUploader->addVideoStream(videoInfo, len, (char *)data.bytes, totalSize);
}

- (void)addAudioStream:(NSDictionary *)upAudioInfo length:(long)len data:(NSData *)data totalSize:(long)totalSize {
//    streamsdk::UpAudioInfo audioInfo;
//    audioInfo.timeScale = [upAudioInfo[UPLOAD_INFO_TIMESCALE] longLongValue];
//    audioInfo.bitRate = [upAudioInfo[UPLOAD_INFO_BITRATE] longLongValue];
//    audioInfo.channelCount = [upAudioInfo[UPLOAD_AUDIO_INFO_CHANNEL_COUNT] longLongValue];
//    audioInfo.sampleSize = [upAudioInfo[UPLOAD_AUDIO_INFO_SAMPLE_SIZE] longLongValue];
//    audioInfo.sampleRate = [upAudioInfo[UPLOAD_AUDIO_INFO_SAMPLE_RATE] longLongValue];
//    streamUploader->addAudioStream(audioInfo, 0, NULL, totalSize);
}

- (void)setParams:(NSString *)key value:(NSString *)value {
    
}

- (void)startPushingStream:(NSDictionary *)upSample length:(long)len data:(NSData *)data totalSize:(long)totalSize {
    if (!_videoStreamAdded) {
        if (_delegate && [_delegate respondsToSelector:@selector(svpLiveUploadEngineFailedWithError:)]) {
            [_delegate svpLiveUploadEngineFailedWithError:SVPLiveAddVideoStreamError];
        }
        return;
    } else if (!_audioStreamAdded) {
        if (_delegate && [_delegate respondsToSelector:@selector(svpLiveUploadEngineFailedWithError:)]) {
            [_delegate svpLiveUploadEngineFailedWithError:SVPLiveAddAudioStreamError];
        }
        return;
    }
    
//    streamsdk::UpSample sample;
//    sample.index = [upSample[UPLOAD_SAMPLE_INFO_STREAM_TYPE] boolValue]?(streamsdk::UpSample::STE_AUDIO):(streamsdk::UpSample::STE_VIDEO);
//    sample.keyFrame = [upSample[UPLOAD_SAMPLE_INFO_IS_KEY_FRAME] boolValue];
//    sample.time = [upSample[UPLOAD_SAMPLE_INFO_TIME] longLongValue];
//    sample.ctsDelta = [upSample[UPLOAD_SAMPLE_INFO_CTS_DELTA] longLongValue];
//    // 开始推流
//    long ret = streamUploader->putSample(sample, len, (char *)data.bytes, totalSize);
//    NSLog(@"---->>>> ret : %@ index : %@ time : %@",@(ret),@(sample.index),@(sample.time));
}

- (void)stopPushingStream {
//    streamUploader->close();
}

- (void)reopenStreamUploader {
//    streamUploader->reOpen();
}

//- (SVPUploadInfo *)getUploadInfo {
//    streamsdk::UploadStatistic uploadStatistic;
//    long ret = streamUploader->getStatus(uploadStatistic);
//    SVPUploadInfo *uploadInfo = [SVPUploadInfo sharedInstance];
//    uploadInfo.statusCode = ret;
//    if(ret == 0){
//        uploadInfo.time = uploadStatistic.time;
//        uploadInfo.remainingTime = uploadStatistic.remainingTime;
//        uploadInfo.speed = uploadStatistic.speed;
//        uploadInfo.dropCount = uploadStatistic.dropCount;
//        uploadInfo.cacheDuration = uploadStatistic.cacheDurtion;
//    }
//    return uploadInfo;
//}
//
//- (void)dealloc {
//    delete streamUploader;
//}

@end
