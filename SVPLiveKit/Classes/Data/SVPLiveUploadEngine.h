//
//  SVPLiveUploadEngine.h
//  DemoLiveStreaming
//
//  Created by yongqingguo on 16/3/22.
//  Copyright © 2016年 gyq. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SVPLiveConfiguration.h"

@protocol SVPLiveUploadEngineDelegate <NSObject>

@optional

/**
 *  推流错误
 *
 *  @param errorCode 错误码
 */
- (void)svpLiveUploadEngineFailedWithError:(NSInteger)errorCode;

@end

@interface SVPUploadInfo : NSObject

@property(nonatomic,assign) long statusCode; //状态码，0为正常，非0不正常
@property(nonatomic,assign) long long time; // 发送时间，单位毫秒
@property(nonatomic,assign) long long remainingTime; // 单位毫秒
@property(nonatomic,assign) long long speed; // 上传速度 bytes/s
@property(nonatomic,assign) long long dropCount; // 丢Frame
@property(nonatomic,assign) long long cacheDuration; // 缓存总时长


+ (instancetype)sharedInstance;

@end

/**
 *  直播推流引擎
 */
@interface SVPLiveUploadEngine : NSObject

/**
 *  推流相关代理
 */
@property(nonatomic,assign) id<SVPLiveUploadEngineDelegate>delegate;
/**
 *  视频参数是否已经添加
 */
@property(nonatomic,assign) BOOL videoStreamAdded;
/**
 *  音频参数是否已经添加
 */
@property(nonatomic,assign) BOOL audioStreamAdded;

/**
 初始化方法

 @param url 推流地址
 @param filePath 录制的flv本地保存路径
 @return 返回SVPLiveUploadEngine对象
 */
- (instancetype)initWithURL:(NSString *)url filePath:(NSString *)filePath;

/**
 *  添加视频流参数信息
 *  视频参数信息在每个直播录制过程中只需调用一次即可，可在相应函数中做控制
 *
 *  @param upVideoInfo {@"timeScale":@"1000",@"bitRate":@"",@"width":@"",@"height":@"",@"frameRate":@""}
 *  @param len         字节数
 *  @param data        视频数据
 *  @param totalSize   默认为0
 */
- (void)addVideoStream:(NSDictionary *)upVideoInfo length:(long)len data:(NSData *)data totalSize:(long)totalSize;

/**
 *  添加音频流参数信息
 *  音频参数信息在每个直播录制过程中只需调用一次即可，可在相应函数中做控制
 *
 *  @param upAudioInfo {@"timeScale":@"1000",@"bitRate":@"",@"channelCount":@"1",@"sampleSize":@"2048",@"sampleRate":@"44100"}
 *  @param len         字节数
 *  @param data        音频数据
 *  @param totalSize   默认为0
 */
- (void)addAudioStream:(NSDictionary *)upAudioInfo length:(long)len data:(NSData *)data totalSize:(long)totalSize;

/**
 *  设置相关参数
 *
 *  @param key   参数名
 *  @param value 参数值
 */
- (void)setParams:(NSString *)key value:(NSString *)value;

/**
 *  开始推流
 *
 *  @param upSample  {@"streamType":@"[0表示视频，1表示音频]",@"keyFrame":@"[1表示是关键帧，0不是]",@"time":@"",@"ctsDelta":@"0"}
 *  @param len       字节数
 *  @param data      视频/音频数据
 *  @param totalSize 默认为0
 */
- (void)startPushingStream:(NSDictionary *)upSample length:(long)len data:(NSData *)data totalSize:(long)totalSize;

/**
 *  停止推流
 */
- (void)stopPushingStream;

/**
 *  网络状态差，出错时尝试reopen去重新连接
 */
-(void) reopenStreamUploader;

/**
 *  抓取上传信息
 *
 *  @return 返回推流相关的信息
 */
- (SVPUploadInfo *)getUploadInfo;

@end
