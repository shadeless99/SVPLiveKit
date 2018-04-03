//
//  SVPLive.h
//  DemoLiveStreaming
//
//  Created by yongqingguo on 16/3/22.
//  Copyright © 2016年 gyq. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
@class SVPLiveCamera;
@class SVPLiveConfiguration;
@class SVPLiveUploadEngine;
@class SVPUploadInfo;

/**
 *  定义直播错误码
 */
typedef NS_ENUM(NSUInteger,SVPLiveErrorCode) {
    /**
     *  设备使用权限获取失败
     */
    SVPLiveCaptureAuthorizationError = 1,
    /**
     *  硬件设备获取失败
     */
    SVPLiveCaptureSessionError = 2,
    /**
     *  推流连接失败
     */
    SVPLiveOpenRtmpURLError = 3,
    /**
     *  推流视频参数信息没有添加
     */
    SVPLiveAddVideoStreamError = 4,
    /**
     *  推流音频参数信息没有添加
     */
    SVPLiveAddAudioStreamError = 5,
    /**
     *  推流失败
     */
    SVPLivePutSampleError = 6,
};

/**
 *  定义当前直播节目的播放状态
 */
typedef NS_ENUM(NSUInteger,SVPLiveStatus) {
    /**
     *  未知节目状态
     */
    SVPLiveStatusUnkonwn,
    /**
     *  节目未开始
     */
    SVPLiveStatusNotStarted,
    /**
     *  节目已初始化
     */
    SVPLiveStatusInit,
    /**
     *  节目正在直播
     */
    SVPLiveStatusLiving,
    /**
     *  节目已暂停
     */
    SVPLiveStatusPause,
    /**
     *  节目已结束
     */
    SVPLiveStatusStopped,
};

@protocol SVPLiveDelegate <NSObject>

@required

/**摄像头预览图层加载成功*/
- (void)svpLiveDidCaptureSessionLoadSuccess;

@optional

- (void)svpLiveDidCaptureSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;

@end

/**
 *  用于实现用户与服务器进行实时直播的功能
 *  1.与服务端通信，创建节目，返回节目id
 *  2.根据拿到的节目id开始直播视频录制及推流操作
 */
@interface SVPLive : NSObject

/**
 *  委托对象
 */
@property(nonatomic,weak) id<SVPLiveDelegate>delegate;
/**
 *  音频/视频参数配置
 */
@property(nonatomic,strong,readonly) SVPLiveConfiguration *configuration;
/**
 *  摄像头
 */
@property(nonatomic,strong,readonly) SVPLiveCamera *camera;
/**
 *  直播推流引擎
 */
@property(nonatomic,strong,readonly) SVPLiveUploadEngine *uploadEngine;
/**
 *  当前直播状态
 */
@property(nonatomic,assign,readonly) SVPLiveStatus status;
/**
 *  节目是否已暂停
 */
@property(nonatomic,assign,readonly,getter=isPaused) BOOL paused;

/**
 *  使用配置信息进行初始化
 *
 *  @param configuration SVPLive需要的参数配置对象
 *  @param completion    session设置成功后回调
 *
 *  @return 返回SVPLive对象
 */
- (instancetype)initWithConfiguration:(SVPLiveConfiguration *)configuration completionHandler:(void (^)(void))completion;

#pragma mark - 直播

/**
 *  开始直播
 */
- (void)startLiving;

/**
 *  暂停直播
 */
- (void)pauseLiving;

/**
 *  暂停后继续直播
 */
- (void)resumeLiving;

/**
 *  停止直播
 */
- (void)stopLiving;

/**
 *  闪光灯切换
 *
 *  @param openOrNot  YES，开启闪光灯；NO，关闭闪光灯
 *  @param completion 完成回调
 */
- (void)switchFlashlight:(BOOL)openOrNot completion:(void (^)(void))completion;

/**
 *  抓取推流信息
 *
 *  @return 返回SVPUploadInfo对象
 */
- (SVPUploadInfo *)getUploadInfo;

/**
 *  网络状态差，出错时尝试reopen去重新连接
 */
- (void)reopenStreamUploader;
/**
 *  获取当前音量大小
 *
 *  @return <#return value description#>
 */
- (UInt64)getMicroInputVolume;

/**
 *  切换前后摄像头
 */
- (void)switchCamera:(void(^)(NSInteger position))block;

/**
 *  手动对焦
 *
 *  @param point <#point description#>
 */
- (void)foucusPoint:(CGPoint)point;

/**
 *  检查设备使用权限
 *
 *  @param completion 结束回调
 */
+ (void)checkDevicePermissionOnCompletion:(void (^)(BOOL success))completion;

+ (void)setCacheDuration:(NSString *)string;
+ (NSString*)getCacheDuration;

/**
 保存录制文件到本地
 */
+ (void)saveLocalFile;

/**
 *  获取本地保存的所有flv视频
 *
 *  @return 返回所有flv列表
 */
+ (NSArray *)getLocalFlvFiles;

@end
