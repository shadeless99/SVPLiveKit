//
//  SVPLiveCamera.m
//  DemoLiveStreaming
//
//  Created by yongqingguo on 16/3/22.
//  Copyright © 2016年 gyq. All rights reserved.
//

#import "SVPLiveCamera.h"
#import "SVPLive.h"
#import "SVPLiveCamera+H264Encoder.h"
#import "SVPLiveCamera+AACEncoder.h"
#import "UIImage+Resize.h"
#import "SVPLivelogger.h"

// 视频/音频文件默认存储路径documents/live/
#define DEFAULT_SAVED_TEMP_FILE_PATH [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"live"]

#define iphone4SWidthInFullScreen 480.f

/**
 *  获取视频帧队列
 *
 *  @return 返回视频帧队列，用于顺序写入视频帧
 */
static dispatch_queue_t dispatch_get_living_video_queue() {
    static dispatch_queue_t living_video_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        living_video_queue = dispatch_queue_create("com.sina.svp.live.video", DISPATCH_QUEUE_SERIAL);
    });
    return living_video_queue;
}

/**
 *  获取音频帧队列
 *
 *  @return 返回音频帧队列，用于顺序写入音频帧
 */
static dispatch_queue_t dispatch_get_living_audio_queue() {
    static dispatch_queue_t living_audio_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        living_audio_queue = dispatch_queue_create("com.sina.svp.live.audio", DISPATCH_QUEUE_SERIAL);
    });
    return living_audio_queue;
}

/**
 *  直播帧写入数据队列
 *
 *  @return 返回直播帧队列
 */
static dispatch_queue_t dispatch_get_living_queue(){
    static dispatch_queue_t living_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        living_queue = dispatch_queue_create("com.sina.svp.living", DISPATCH_QUEUE_SERIAL);
    });
    return living_queue;
}

/**
 *  包含摄像头相关硬件的初始化
 *  用于音视频采集回调实现captureOutput:didOutputSampleBuffer:fromConnection:才可以完成获取采样数据的操作
 */
@interface SVPLiveCamera()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate,SVPLiveCameraDelegate>

/**
 *  用户已经授权
 *  摄像头和麦克风的使用需要得到用户授权
 */
@property(nonatomic,assign) BOOL userAuthorized;
/**
 *  当前选择的设备
 */
@property(nonatomic,strong,readwrite) AVCaptureDevice *currentCamera;
/**
 *  视频拍摄对象AVCaptureSession
 */
@property(nonatomic,strong,readwrite) AVCaptureSession *captureSession;
/**
 *  视频预览层
 */
@property(nonatomic,strong,readwrite) AVCaptureVideoPreviewLayer *previewLayer;
/**
 *  视频输入
 */
@property(nonatomic,strong) AVCaptureDeviceInput *inputVideo;
/**
 *  音频输入
 */
@property(nonatomic,strong) AVCaptureDeviceInput *inputAudio;
/**
 *  视频输出
 */
@property(nonatomic,strong) AVCaptureVideoDataOutput *videoDataOutput;
/**
 *  音频输出
 */
@property(nonatomic,strong) AVCaptureAudioDataOutput *audioDataOutput;
/**
 *  视频采集设备，后置摄像头
 */
@property(nonatomic,strong) AVCaptureDevice *deviceBackCamera;
/**
 *  视频采集设备，前置摄像头
 */
@property(nonatomic,strong) AVCaptureDevice *deviceFrontCamera;
/**
 *  音频采集设备，麦克风
 */
@property(nonatomic,strong) AVCaptureDevice *deviceAudio;
/**
 *  将编码后的帧数据写入本地
 */
@property(nonatomic,strong,readwrite) NSFileHandle *h264FileHandler;
/**
 *  将编码后的音频帧数据写入本地
 */
@property(nonatomic,strong,readwrite) NSFileHandle *aacFileHandler;
/**
 *  保存的h264文件绝对路径
 */
@property(nonatomic,copy) NSString *h264File;
/**
 *  保存的aac文件绝对路径
 */
@property(nonatomic,copy) NSString *aacFile;
/**
 *  是否是第一帧视频帧
 */
@property(nonatomic,assign,readwrite) BOOL isFirstVideoSampleBuffer;
/**
 *  是否是第一帧音频帧
 */
@property(nonatomic,assign,readwrite) BOOL isFirstAudioSampleBuffer;

/**
 *  时间戳起点，单位毫秒，后面的每一帧数据的时间戳以此为基准
 */
@property(nonatomic,assign,readwrite) NSTimeInterval originTimestamp;
/**
 *  录入声音大小
 */
@property(nonatomic,assign,readwrite)   UInt64  microVolume;
@property(nonatomic,assign,readwrite)   UInt32  microVolumeCount;

@property(nonatomic,assign,readwrite)   BOOL  isConfiging;
@property(nonatomic,assign,readwrite) BOOL isCameraStopped;
@property(nonatomic,strong) NSMutableArray *watermarks;  // 水印

@end

@implementation SVPLiveCamera

#pragma mark - LifeCycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _outputPath = DEFAULT_SAVED_TEMP_FILE_PATH;
        _userAuthorized = YES;
        _isFirstVideoSampleBuffer = YES;
        _isFirstAudioSampleBuffer = YES;
        _originTimestamp = [[NSDate date] timeIntervalSince1970];
    }
    return self;
}

- (instancetype)initWithOutputPath:(NSString *)path {
    self = [self init];
    if (self) {
        if (path) {
            _outputPath = path;
        }
        _screenWidth   = VIDEO_WIDTH_0;
        _screenHeight  = VIDEO_HEIGHT_0;
    }
    return self;
}

-(instancetype) initWithOutputPath:(NSString *)path screenRatio:(NSInteger)screenRatio{
    self = [self init];
    if (self) {
        if (path) {
            _outputPath = path;
        }
        _screenRatio = screenRatio;
        if (_screenRatio && _screenRatio == 1){
            _screenWidth   = VIDEO_WIDTH_1;
            _screenHeight  = VIDEO_HEIGHT_1;
        }else{
            _screenWidth   = VIDEO_WIDTH_0;
            _screenHeight  = VIDEO_HEIGHT_0;
        }
    }
    return self;
}

- (void)dealloc {
//    [self stopCamera];
}

#pragma mark - Public

- (void)openCameraOnCompletion:(void (^)(void))completion {
    // 默认已授权
    self.userAuthorized = YES;
    
    __weak typeof (self)weakSelf = self;
    // 判断当前的摄像头用户权限
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusAuthorized: {
            self.userAuthorized = YES;
        }
            break;
        case AVAuthorizationStatusDenied: {
            self.userAuthorized = NO;
        }
            break;
        case AVAuthorizationStatusNotDetermined: {
            // 当用户没有授权相关权限的时候，先中断初始化操作，直到用户对请求权限进行操作才继续执行初始化操作
            dispatch_suspend(dispatch_get_living_queue());
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                __strong typeof (self) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                strongSelf.userAuthorized = granted;
                dispatch_resume(dispatch_get_living_queue());
            }];
        }
            break;
        default: {
            self.userAuthorized = NO;
        }
            break;
    }
    
    // 判断当前的麦克风用户权限
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]) {
        case AVAuthorizationStatusAuthorized: {
            self.userAuthorized = YES;
        }
            break;
        case AVAuthorizationStatusDenied: {
            self.userAuthorized = NO;
        }
            break;
        case AVAuthorizationStatusNotDetermined: {
            // 当用户没有授权相关权限的时候，先终端初始化操作，知道用户对请求权限进行操作才继续执行初始化操作
            dispatch_suspend(dispatch_get_living_queue());
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
                __strong typeof (self) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                strongSelf.userAuthorized = granted;
                dispatch_resume(dispatch_get_living_queue());
            }];
        }
            break;
        default: {
            self.userAuthorized = NO;
        }
            break;
    }
    
    // 初始化设备信息
    dispatch_async(dispatch_get_living_queue(), ^{
        
        // 没有权限处理
        if (!self.userAuthorized) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof (self)strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                if ([strongSelf.delegate respondsToSelector:@selector(svpLiveCameraDidCaptureSessionLoadFailed:)]) {
                    [strongSelf.delegate svpLiveCameraDidCaptureSessionLoadFailed:SVPLiveCaptureAuthorizationError];
                }
            });
            return;
        }
        
        // 获取视频输入设备
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        for (AVCaptureDevice *device in devices) {
            if (device.position == AVCaptureDevicePositionFront) {
                self.deviceFrontCamera = device;
            } else if (device.position == AVCaptureDevicePositionBack) {
                self.deviceBackCamera = device;
            }
        }
        if (devices.count == 2) {
            self.currentCamera = self.deviceBackCamera;
        } else if (devices.count == 1) {
            self.currentCamera = devices.firstObject;
        } else {
            NSLog(@"captureError = %@",NSLocalizedString(@"load capture audio device failed", @"获取设备麦克风失败"));
            // 摄像头不可用
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof (self) strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                if ([strongSelf.delegate respondsToSelector:@selector(svpLiveCameraDidCaptureSessionLoadFailed:)]) {
                    [strongSelf.delegate svpLiveCameraDidCaptureSessionLoadFailed:SVPLiveCaptureSessionError];
                }
            });
            return;
        }
        
        // 获取音频输入设备
        self.deviceAudio = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        if (!self.deviceAudio) {
            NSLog(@"captureError = %@",NSLocalizedString(@"load capture audio device failed", @"获取设备摄像头失败"));
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof (self)strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                if ([strongSelf.delegate respondsToSelector:@selector(svpLiveCameraDidCaptureSessionLoadFailed:)]) {
                    [strongSelf.delegate svpLiveCameraDidCaptureSessionLoadFailed:SVPLiveCaptureSessionError];
                }
            });
            return;
        }
        
        // 视频设备输入
        self.inputVideo = [AVCaptureDeviceInput deviceInputWithDevice:self.currentCamera error:nil];
        
        // 音频设备输入
        self.inputAudio = [AVCaptureDeviceInput deviceInputWithDevice:self.deviceAudio error:nil];
        
        // 添加视频输入到session
        _captureSession = [[AVCaptureSession alloc] init];
        [self.captureSession beginConfiguration];
        _isConfiging = YES;
        
        if ([self.captureSession canAddInput:self.inputVideo]) {
            [self.captureSession addInput:self.inputVideo];
        } else {
            NSLog(@"captureError = %@",NSLocalizedString(@"add camera input failed", @"添加摄像头输入失败"));
            // 添加摄像头输入失败
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof (self)strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                if ([strongSelf.delegate respondsToSelector:@selector(svpLiveCameraDidCaptureSessionLoadFailed:)]) {
                    [strongSelf.delegate svpLiveCameraDidCaptureSessionLoadFailed:SVPLiveCaptureSessionError];
                }
            });
            return;
        }
        
        if ([self.captureSession canAddInput:self.inputAudio]) {
            [self.captureSession addInput:self.inputAudio];
        } else {
            NSLog(@"captureError = %@",NSLocalizedString(@"add micro input failed", @"添加麦克风输入失败"));
            // 添加麦克风输入失败
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof (self)strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                if ([strongSelf.delegate respondsToSelector:@selector(svpLiveCameraDidCaptureSessionLoadFailed:)]) {
                    [strongSelf.delegate svpLiveCameraDidCaptureSessionLoadFailed:SVPLiveCaptureSessionError];
                }
            });
            return;
        }
        
        // 添加视频输出
        self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        if ([self.captureSession canAddOutput:self.videoDataOutput]) {
            [self.captureSession addOutput:self.videoDataOutput];
        }
        self.videoDataOutput.videoSettings = @{
                                               (id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)};
        // 丢掉迟来的帧
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
        [self.videoDataOutput setSampleBufferDelegate:nil queue:dispatch_get_living_video_queue()];
        
        // 添加音频输出
        self.audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
        if ([self.captureSession canAddOutput:self.audioDataOutput]) {
            [self.captureSession addOutput:self.audioDataOutput];
        }
        [self.audioDataOutput setSampleBufferDelegate:nil queue:dispatch_get_living_audio_queue()];
        
        // 设置捕获帧fps（通过lock与unlock来获取设备的配置属性的独占访问权限）
        if ([self.deviceBackCamera lockForConfiguration:NULL]) {
            // 将最小值与最大值设置成一样来确保帧速率恒定
            [self.deviceBackCamera setActiveVideoMaxFrameDuration:CMTimeMake(1, FRAME_RATE_HIGH)];
            [self.deviceBackCamera setActiveVideoMinFrameDuration:CMTimeMake(1, FRAME_RATE_HIGH)];
            [self.deviceBackCamera unlockForConfiguration];
        }
        if ([self.deviceFrontCamera lockForConfiguration:NULL]) {
            [self.deviceFrontCamera setActiveVideoMaxFrameDuration:CMTimeMake(1, FRAME_RATE_HIGH)];
            [self.deviceFrontCamera setActiveVideoMinFrameDuration:CMTimeMake(1, FRAME_RATE_HIGH)];
            [self.deviceFrontCamera unlockForConfiguration];
        }
        
        // 设置捕获视频的分辨率（采集解析度）
        [self setFrameSizeForCamera];
        
        [self.captureSession commitConfiguration];
        _isConfiging = NO;
        @try {
            [self.captureSession startRunning];
            
            NSLog(@"before add previewlayer");
            
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof (self)strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                NSLog(@"begin to add previewlayer");
                if (completion) {
                    completion();
                }
                NSLog(@"after add previewlayer");
                
                if ([strongSelf.delegate respondsToSelector:@selector(svpLiveCameraDidCaptureSessionLoadSuccess)]) {
                    [strongSelf.delegate svpLiveCameraDidCaptureSessionLoadSuccess];
                }
            });
        } @catch (NSException *exception) {
            log_error(exception.reason);
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof (self)strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                
                if ([strongSelf.delegate respondsToSelector:@selector(svpLiveCameraDidCaptureSessionLoadFailed:)]) {
                    [strongSelf.delegate svpLiveCameraDidCaptureSessionLoadFailed:-1];
                }
            });
        } @finally {
            
        }
    });
}

- (void)startCamera {
    if (!self.userAuthorized) {
        return;
    }
    
    if (self.captureSession) {
#if SUPPORT_H264_ENCODER
        if (!self.h264Encoder) {
            [self initH264EncoderWithBitrate:self.bitrate];
        }
        self.h264Encoder.delegate = self;
#endif
#if SUPPORT_AAC_ENCODER
        if (!self.aacEncoder) {
            [self initAACEncoder];
        }
        self.aacEncoder.delegate = self;
#endif
    
        [self.captureSession beginConfiguration];
        NSLog(@"开始录制视频和音频");
        [self.videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_living_video_queue()];
        [self.audioDataOutput setSampleBufferDelegate:self queue:dispatch_get_living_audio_queue()];
        
        // 设置捕获帧fps（通过lock与unlock来获取设备的配置属性的独占访问权限）
        if ([self.deviceBackCamera lockForConfiguration:NULL]) {
            // 将最小值与最大值设置成一样来确保帧速率恒定
            [self.deviceBackCamera setActiveVideoMaxFrameDuration:CMTimeMake(1, FRAME_RATE_HIGH)];
            [self.deviceBackCamera setActiveVideoMinFrameDuration:CMTimeMake(1, FRAME_RATE_HIGH)];
            [self.deviceBackCamera unlockForConfiguration];
        }
        if ([self.deviceFrontCamera lockForConfiguration:NULL]) {
            [self.deviceFrontCamera setActiveVideoMaxFrameDuration:CMTimeMake(1, FRAME_RATE_HIGH)];
            [self.deviceFrontCamera setActiveVideoMinFrameDuration:CMTimeMake(1, FRAME_RATE_HIGH)];
            [self.deviceFrontCamera unlockForConfiguration];
        }
        
        // 设置捕获视频的分辨率（采集解析度）
        [self setFrameSizeForCamera];

        
        [self.captureSession commitConfiguration];
        _isConfiging = NO;
        if (!self.captureSession.isRunning) {
            @try {
                [self.captureSession startRunning];
                
                NSFileManager *fileManager = [NSFileManager defaultManager];
                [fileManager createDirectoryAtPath:_outputPath withIntermediateDirectories:YES attributes:nil error:nil];
                _h264File = [_outputPath stringByAppendingPathComponent:@"live_movie.h264"];
                [fileManager removeItemAtPath:_h264File error:nil];
                [fileManager createFileAtPath:_h264File contents:nil attributes:nil];
                
                _aacFile = [_outputPath stringByAppendingPathComponent:@"live_sound.aac"];
                [fileManager removeItemAtPath:_aacFile error:nil];
                [fileManager createFileAtPath:_aacFile contents:nil attributes:nil];
                
                _h264FileHandler = [NSFileHandle fileHandleForWritingAtPath:_h264File];
                _aacFileHandler = [NSFileHandle fileHandleForWritingAtPath:_aacFile];
            } @catch (NSException *exception) {
                log_error(exception.reason);
            } @finally {
                
            }
        }
    }
}
/**
 *  设置采集视频分辨率
 */
- (void)setFrameSizeForCamera {
    if (self.captureSession) {
        if (_currentCamera == self.deviceFrontCamera) {
            // 简单判断iPhone4s及之前的机型
            if ([UIScreen mainScreen].bounds.size.width <= iphone4SWidthInFullScreen) {
                if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
                    [self.captureSession setSessionPreset:AVCaptureSessionPreset640x480];
                    return;
                }
            }
        }
        if ([self.captureSession canSetSessionPreset:AVCaptureSessionPresetiFrame1280x720]) {
            [self.captureSession setSessionPreset:AVCaptureSessionPresetiFrame1280x720];
        } else if ([self.captureSession canSetSessionPreset:AVCaptureSessionPresetiFrame960x540]) {
            [self.captureSession setSessionPreset:AVCaptureSessionPresetiFrame960x540];
        } else if([self.captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
            [self.captureSession setSessionPreset:AVCaptureSessionPreset640x480];
        }
    }
}

- (void)pauseCamera {
    if (!self.userAuthorized) {
        return;
    }
    
    if (self.captureSession) {
        [self.captureSession beginConfiguration];
        _isConfiging = YES;
        NSLog(@"视频和音频录制暂停");
        [self.videoDataOutput setSampleBufferDelegate:nil queue:dispatch_get_living_video_queue()];
        [self.audioDataOutput setSampleBufferDelegate:nil queue:dispatch_get_living_audio_queue()];
        [self.captureSession commitConfiguration];
        _isConfiging = NO;
    }
    @try {
        [self.captureSession stopRunning];
        self.isCameraStopped = YES;
        NSLog(@"pause:isRunning:%d\n",self.captureSession.isRunning);
    } @catch (NSException *exception) {
        log_error(exception.reason);
    } @finally {
        
    }
}

- (void)resumeCamera {
    if (!self.userAuthorized) {
        return;
    }
    @try {
        if (!self.captureSession.isRunning) {
            [self.captureSession startRunning];
            [self initH264EncoderWithBitrate:self.bitrate];
            self.h264Encoder.delegate = self;
        }
        self.isCameraStopped = NO;
        
        if (self.captureSession) {
            [self.captureSession beginConfiguration];
            _isConfiging = YES;
            NSLog(@"视频和音频录制继续");
            [self.videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_living_video_queue()];
            [self.audioDataOutput setSampleBufferDelegate:self queue:dispatch_get_living_audio_queue()];
            [self.captureSession commitConfiguration];
            _isConfiging = NO;
        }
    } @catch (NSException *exception) {
        log_error(exception.reason);
    } @finally {
        
    }
}

- (void)stopCamera {
    if (!self.userAuthorized) {
        return;
    }
    if (self.captureSession) {
        [self.captureSession beginConfiguration];
        _isConfiging = YES;
        NSLog(@"音频和视频录制结束");
        [self.videoDataOutput setSampleBufferDelegate:nil queue:dispatch_get_living_video_queue()];
        [self.audioDataOutput setSampleBufferDelegate:nil queue:dispatch_get_living_audio_queue()];
        [self.captureSession removeInput:self.inputVideo];
        [self.captureSession removeInput:self.inputAudio];
        [self.captureSession removeOutput:self.videoDataOutput];
        [self.captureSession removeOutput:self.audioDataOutput];
        [self.captureSession commitConfiguration];
        _isConfiging = NO;
    }
    
    if (self.captureSession.isRunning) {
        @try {
            [self.captureSession stopRunning];
        } @catch (NSException *exception) {
            log_error(exception.reason);
        } @finally {
            
        }
    }
    self.currentCamera = nil;
    self.captureSession = nil;
    
    [_h264FileHandler closeFile];
    _h264FileHandler = NULL;
    
    [_aacFileHandler closeFile];
    _aacFileHandler = NULL;
    
#if SUPPORT_H264_ENCODER
    [self.h264Encoder End];
#endif
    self.isCameraStopped = YES;
}

- (void)switchTorch:(BOOL)openOrNot completion:(void (^)(void))completion {
    if (!self.userAuthorized) {
        return;
    }
    __weak typeof (self)weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof (self)strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        // 如果为后置摄像头的话就判断是否可以打开闪光灯
        if (strongSelf.deviceBackCamera && strongSelf.currentCamera == strongSelf.deviceBackCamera) {
            if([strongSelf.currentCamera isTorchAvailable]) {
                if (openOrNot) {
                    if ([strongSelf.currentCamera torchMode] == AVCaptureTorchModeOff) {
                        [strongSelf.currentCamera lockForConfiguration:nil];
                        [strongSelf.currentCamera setTorchMode:AVCaptureTorchModeOn];
                        [strongSelf.currentCamera unlockForConfiguration];
                    }
                } else {
                    if ([strongSelf.currentCamera torchMode] == AVCaptureTorchModeOn) {
                        [strongSelf.currentCamera lockForConfiguration:nil];
                        [strongSelf.currentCamera setTorchMode:AVCaptureTorchModeOff];
                        [strongSelf.currentCamera unlockForConfiguration];
                    }
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion();
            }
        });
    });
}

- (void)switchCameraWithBlock:(void(^)(NSInteger position))block {
    if (!self.userAuthorized) {
        return;
    }
    if(_isConfiging){
        return;
    }
    __weak typeof (self)weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof (self)strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        @try {
            NSInteger cameraPosition = 1;
            if (strongSelf.deviceBackCamera && strongSelf.deviceFrontCamera) {
                if (strongSelf.captureSession.isRunning){
                    if (strongSelf.isConfiging) {
                        return;
                    }
                    [strongSelf.captureSession stopRunning];
                }
                
                [strongSelf.captureSession beginConfiguration];
                strongSelf.isConfiging = YES;
                [strongSelf.captureSession removeInput:strongSelf.inputVideo];
                [strongSelf.captureSession removeOutput:strongSelf.videoDataOutput];
                
                if (strongSelf.currentCamera == strongSelf.deviceBackCamera) {
                    strongSelf.currentCamera = strongSelf.deviceFrontCamera;
                    cameraPosition = 0;
                } else if (strongSelf.currentCamera == strongSelf.deviceFrontCamera) {
                    strongSelf.currentCamera = strongSelf.deviceBackCamera;
                    cameraPosition = 1;
                }
                // 设置为自动对焦
                if ([strongSelf.currentCamera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                    NSError *error = nil;
                    [strongSelf.currentCamera lockForConfiguration:&error];
                    if(!error){
                        [strongSelf.currentCamera setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
                        [strongSelf.currentCamera unlockForConfiguration];
                    }
                }
                NSLog(@"切换摄像头，当前状态为:%@!",@(cameraPosition));
                
                [strongSelf setFrameSizeForCamera];
                //添加视频输入
                strongSelf.inputVideo = [[AVCaptureDeviceInput alloc] initWithDevice:strongSelf.currentCamera error:nil];
                if([strongSelf.captureSession canAddInput:strongSelf.inputVideo]){
                    [strongSelf.captureSession addInput:strongSelf.inputVideo];
                }
                //添加视频输出
                strongSelf.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
                if ([strongSelf.captureSession canAddOutput:strongSelf.videoDataOutput]) {
                    [strongSelf.captureSession addOutput:strongSelf.videoDataOutput];
                }
                strongSelf.videoDataOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
                [strongSelf.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
                if (cameraPosition == 0) {
                    AVCaptureConnection * videoCaptureConnection = [strongSelf.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
                    if (videoCaptureConnection != nil) {
                        if ([videoCaptureConnection isVideoOrientationSupported]) {
                            [videoCaptureConnection setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
                        }
                        if ([videoCaptureConnection isVideoMirroringSupported]) {
                            [videoCaptureConnection setVideoMirrored:YES];
                        }
                    }
                }
                
                [strongSelf.captureSession commitConfiguration];
                strongSelf.isConfiging = NO;
                if (![strongSelf.captureSession isRunning]) {
                    if (strongSelf.isConfiging) {
                        return;
                    }
                    [strongSelf.captureSession startRunning];
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (block) {
                    block(cameraPosition);
                }
            });
        } @catch (NSException *exception) {
            log_error(exception.reason);
        } @finally {
            
        }
    });
}


#pragma mark - camera foucs
-(void)foucusPoint:(CGPoint) point{
    if (_currentCamera.isFocusPointOfInterestSupported &&[_currentCamera isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error = nil;
        [_currentCamera lockForConfiguration:&error];
        if(!error){
            [_currentCamera setFocusPointOfInterest:point];
            [_currentCamera setFocusMode:AVCaptureFocusModeAutoFocus];
            [_currentCamera unlockForConfiguration];
            
            [self performSelector:@selector(setContinueAutoFocus) withObject:nil afterDelay:1.0];
        }
    }
}

/**
 *  设置为持续自动对焦
 */
- (void)setContinueAutoFocus {
    // 设置为自动对焦
    if ([self.currentCamera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
        NSError *error = nil;
        [self.currentCamera lockForConfiguration:&error];
        if(!error){
            if ([self.currentCamera isSmoothAutoFocusEnabled]) {
                [self.currentCamera setSmoothAutoFocusEnabled:YES];
            }
            [self.currentCamera setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            [self.currentCamera unlockForConfiguration];
        }
    }
}

#pragma mark   AVCaptureAudioDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!self.userAuthorized) {
        return;
    }
    if (self.isCameraStopped) {
        return;
    }
    CFRetain(sampleBuffer);
    __weak typeof (self)weakSelf = self;
    dispatch_async(dispatch_get_living_queue(), ^{
        @autoreleasepool {
            __strong typeof (self)strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            if (captureOutput == strongSelf.videoDataOutput) {
                NSLog(@"取得视频帧");
#if SUPPORT_H264_ENCODER
                NSMutableArray *images = nil;
#if SUPPORT_WATERMASKS
                images = strongSelf.watermarks;
#endif
                [strongSelf encodeH264:sampleBuffer watermasks:images];
                strongSelf.isFirstVideoSampleBuffer = NO;
#endif
            } else if (captureOutput == strongSelf.audioDataOutput) {
                NSLog(@"取得音频帧");
#if SUPPORT_AAC_ENCODER
                if ([strongSelf encodeAAC:sampleBuffer]) {
                    strongSelf.isFirstAudioSampleBuffer = NO;
                }
#endif
            }
            CFRelease(sampleBuffer);
        }
    });
}

- (UInt64)getMicroInputVolume {
    UInt64 volume = 10 * log10((double)_microVolume/_microVolumeCount);
    // DLog(@"当前声音音量 %d 分贝",volume);
    _microVolume = 0;
    _microVolumeCount = 0;
    return volume;
}

- (void)updateWatermarks:(NSArray *)watermarks {
    if (!watermarks || (watermarks && watermarks.count <= 0)) {
        self.watermarks = nil;
        return;
    }
    if (!self.watermarks) {
        self.watermarks = [NSMutableArray array];
    }
    if (watermarks && watermarks.count > 0) {
        NSString *style = ((UIImage *)watermarks[0]).watermarkStyle;
        for (int i = 0; i < self.watermarks.count; i ++) {
            UIImage *img = self.watermarks[i];
            if ([img.watermarkStyle isEqualToString:style]) {
                [self.watermarks removeObject:img];
            }
        }
        [self.watermarks addObjectsFromArray:watermarks];
    }
}

- (void)blankWatermarksWithStyle:(NSString *)style {
    for (int i = 0; i < self.watermarks.count; i ++) {
        UIImage *img = self.watermarks[i];
        if ([img.watermarkStyle isEqualToString:style]) {
            [self.watermarks removeObject:img];
        }
    }
}

@end
