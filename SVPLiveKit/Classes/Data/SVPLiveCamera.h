//
//  SVPLiveCamera.h
//  DemoLiveStreaming
//
//  Created by yongqingguo on 16/3/22.
//  Copyright © 2016年 gyq. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SVPLiveCamera.h"
#import "SVPLiveConfiguration.h"

@protocol SVPLiveCameraDelegate <NSObject>

@optional

#pragma mark - 设备初始化回调

/**
 *  AVCaptureSession加载成功
 */
- (void)svpLiveCameraDidCaptureSessionLoadSuccess;

/**
 *  AVCaptureSession加载失败
 */
- (void)svpLiveCameraDidCaptureSessionLoadFailed:(NSUInteger)errorCode;

#pragma mark - 硬编码后的回调

/**
 *  编码后拿到h264的参数信息sps、pps
 *
 *  @param spsPps 编码后h264的参数信息sps、pps
 *  @param videoInfo 视频参数信息
 */
- (void)svpLiveCameraDidCaptureSpsPps:(NSData *)spsPps upVideoInfo:(NSDictionary *)videoInfo;

/**
 *  编码后拿到AAC的参数信息
 *
 *  @param audioHeader 音频头数据
 *  @param audioInfo   音频参数信息
 */
- (void)svpLiveCameraDidCaptureAudioHeader:(NSData *)audioHeader upAudioInfo:(NSDictionary *)audioInfo;

/**
 *  拿到编码后的视频图像数据
 *
 *  @param encodedData 编码后的视频图像数据
 *  @param timestamp   sample对应的时间戳
 *  @param isVideo     是否是视频帧，对应的是音频帧
 *  @param isKeyframe  是否是关键帧
 */
- (void)svpLiveCameraDidCaptureEncodedData:(NSData *)encodedData timestamp:(long long)timestamp isVideo:(BOOL)isVideo isKeyframe:(BOOL)isKeyframe;

@end

/**
 *  直播摄像头，负责采集视频，编码交由第三方H264HwEncoderImpl完成
 */
@interface SVPLiveCamera : NSObject

/**
 *  代理对象
 */
@property(nonatomic,assign) id<SVPLiveCameraDelegate>delegate;
/**
 *  当前选择的设备
 */
@property(nonatomic,strong,readonly) AVCaptureDevice *currentCamera;
/**
 *  视频拍摄对象AVCaptureSession
 */
@property(nonatomic,strong,readonly) AVCaptureSession *captureSession;
/**
 *  视频预览层
 */
@property(nonatomic,strong,readonly) AVCaptureVideoPreviewLayer *previewLayer;
/**
 *  视频设置
 */
@property(nonatomic,copy) NSDictionary *videoOutputSettings;
/**
 *  视频/音频输出文件夹路径
 */
@property(nonatomic,copy) NSString *outputPath;
/**
 *  将编码后的视频帧数据写入本地
 */
@property(nonatomic,strong,readonly) NSFileHandle *h264FileHandler;
/**
 *  将编码后的音频帧数据写入本地
 */
@property(nonatomic,strong,readonly) NSFileHandle *aacFileHandler;
/**
 *  时间戳起点，单位毫秒，后面的每一帧数据的时间戳以此为基准
 */
@property(nonatomic,assign,readonly) NSTimeInterval originTimestamp;
/**
 *  是否是第一帧视频帧
 */
@property(nonatomic,assign,readonly) BOOL isFirstVideoSampleBuffer;
/**
 *  是否是第一帧音频帧
 */
@property(nonatomic,assign,readonly) BOOL isFirstAudioSampleBuffer;
/**
 *  编码码率
 */
@property(nonatomic,assign) NSInteger bitrate;

/**
 *  屏幕分辨率比例，16：9 或 4：3
 */
@property(nonatomic,assign) NSInteger screenRatio;

/**
 *  屏幕宽度
 */
@property(nonatomic,assign) NSInteger screenWidth;

/**
 *  屏幕高度
 */
@property(nonatomic,assign) NSInteger screenHeight;

/**
 *  初始化摄像头
 *
 *  @param path        视频文件输出文件夹路径
 *  @param previewRect 视频预览窗口大小
 *
 *  @return 返回SVPLiveCamera对象
 */
- (instancetype)initWithOutputPath:(NSString *)path;
@property(nonatomic,assign,readonly) BOOL isCameraStopped;


/**
 *  初始化摄像头
 *
 *  @param path        视频文件输出文件夹路径
 *  @param 屏幕比例      0:16:9 1:4:3
 *
 *  @return 返回SVPLiveCamera对象
 */
- (instancetype)initWithOutputPath:(NSString *)path screenRatio:(NSInteger) screenRatio;

/**
 *  打开摄像头
 */
- (void)openCameraOnCompletion:(void (^)(void))completion;

/**
 *  开始收集数据
 */
- (void)startCamera;

/**
 *  暂停收集数据
 */
- (void)pauseCamera;

/**
 *  暂停后继续收集数据
 */
- (void)resumeCamera;

/**
 *  停止收集数据
 */
- (void)stopCamera;

/**
 *  切换闪光灯
 *
 *  @param openOrNot  开启或关闭
 *  @param completion 完成回调
 */
- (void)switchTorch:(BOOL)openOrNot completion:(void (^)(void))completion;

/**
 *  切换前置/后置摄像头
 *
 *  @param block 完成回调
 */
- (void)switchCameraWithBlock:(void(^)(NSInteger position))block;

/**
 *  获取输入音量大小
 *
 *  @return 音量大小
 */
- (UInt64)getMicroInputVolume;

/**
 *  手动对焦
 *
 *  @param point <#point description#>
 */
- (void)foucusPoint:(CGPoint)point;

/**
 更新水印

 @param watermarks <#watermarks description#>
 */
- (void)updateWatermarks:(NSArray *)watermarks;

/**
 清除水印
 
 @param watermarks 水印样式
 */
- (void)blankWatermarksWithStyle:(NSString *)style;

@end
