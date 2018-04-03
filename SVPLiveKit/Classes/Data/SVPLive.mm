//
//  SVPLive.m
//  DemoLiveStreaming
//
//  Created by yongqingguo on 16/3/22.
//  Copyright © 2016年 gyq. All rights reserved.
//

#import "SVPLive.h"
#import <UIKit/UIKit.h>
#import "SVPLiveCamera.h"
#import "SVPLiveUploadEngine.h"

// 保存录制视频文件到本地
#define SVPLiveSaveLocalFLVFile @"saveLocalFLVFile"
#define SVPLiveOutputPath @"outputpath"
#define SVPLiveFlvFullPath @"flvFullPath"

@interface SVPLive()<SVPLiveCameraDelegate,SVPLiveUploadEngineDelegate,UIAlertViewDelegate>

/**
 *  音频/视频参数配置
 */
@property(nonatomic,strong) SVPLiveConfiguration *configuration;
/**
 *  摄像头
 */
@property(nonatomic,strong,readwrite) SVPLiveCamera *camera;
/**
 *  直播推流引擎
 */
@property(nonatomic,strong,readwrite) SVPLiveUploadEngine *uploadEngine;
/**
 *  当前直播状态
 */
@property(nonatomic,assign,readwrite) SVPLiveStatus status;
/**
 *  节目是否已暂停
 */
@property(nonatomic,assign,readwrite) BOOL paused;

@end

static void (^CheckPermissionCompletion)(BOOL success);

static NSString *cacheDuration = @"";

@implementation SVPLive

#pragma mark - LifeCycle

static dispatch_queue_t dispatch_get_checking_permission_queue() {
    static dispatch_queue_t checking_permission_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        checking_permission_queue = dispatch_queue_create("com.sina.svp.live.video.checkpermission", DISPATCH_QUEUE_SERIAL);
    });
    return checking_permission_queue;
}

+ (instancetype)getInstance {
    static SVPLive *liveInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        liveInstance = [[SVPLive alloc] init];
    });
    return liveInstance;
}

- (instancetype)initWithConfiguration:(SVPLiveConfiguration *)configuration completionHandler:(void (^)(void))completion {
    self = [super init];
    if (self) {
        _configuration = configuration;
        
//        streamsdk::StreamServer::startServer();
        
        _camera = [[SVPLiveCamera alloc] initWithOutputPath:_configuration.outputPath screenRatio:_configuration.screenRatio];
        [[NSUserDefaults standardUserDefaults] setObject:_configuration.outputPath forKey:SVPLiveOutputPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [[NSUserDefaults standardUserDefaults] setObject:_configuration.localSavedFileFullPath forKey:SVPLiveFlvFullPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
        _camera.delegate = self;
        _camera.bitrate = _configuration.bitrate;
        _camera.screenRatio = _configuration.screenRatio;
        
        // 打开摄像头（准备录像）
        [_camera openCameraOnCompletion:completion];
        
        _status = SVPLiveStatusUnkonwn;
        [self addNotificationObservers];
    }
    return self;
}

- (void)dealloc {
    [self removeNotificationObservers];
    
    _camera = nil;
    _configuration = nil;
}

#pragma mark - Public

- (AVCaptureVideoPreviewLayer *)previewLayer {
    return _camera.previewLayer;
}

- (SVPLiveUploadEngine *)uploadEngine {
    if (!_uploadEngine) {
        BOOL saveLocalFile = [[NSUserDefaults standardUserDefaults] boolForKey:SVPLiveSaveLocalFLVFile];
        if (saveLocalFile) {
            _uploadEngine = [[SVPLiveUploadEngine alloc] initWithURL:_configuration.outputPath filePath:_configuration.localSavedFileFullPath];
        } else {
            _uploadEngine = [[SVPLiveUploadEngine alloc] initWithURL:_configuration.outputPath filePath:nil];
        }
    }
    return _uploadEngine;
}

- (void)startLiving {
    [_camera startCamera];
}

- (void)pauseLiving {
    [_camera pauseCamera];
    _paused = YES;
//    [self.uploadEngine stopPushingStream];
}

- (void)resumeLiving {
    [_camera resumeCamera];
    _paused = NO;
//    [self.uploadEngine reopenStreamUploader];
}

- (void)stopLiving {
    [_camera stopCamera];
    _paused = NO;
    
    [self.uploadEngine stopPushingStream];
}

- (void)switchFlashlight:(BOOL)openOrNot completion:(void (^)())completion {
    [_camera switchTorch:openOrNot completion:completion];
}

- (SVPUploadInfo *)getUploadInfo {
    return [self.uploadEngine getUploadInfo];
}

- (void)reopenStreamUploader {
    [self.uploadEngine reopenStreamUploader];
}

- (UInt64)getMicroInputVolume {
    return [_camera getMicroInputVolume];
}

- (void)switchCamera:(void(^)(NSInteger position))block {
    [_camera switchCameraWithBlock:block];
}

- (void)foucusPoint:(CGPoint) point {
    [_camera foucusPoint:point];
}

+ (void)checkDevicePermissionOnCompletion:(void (^)(BOOL))completion {
    if (completion) {
        CheckPermissionCompletion = completion;
    }
    __block BOOL checkCamera = NO;
    __block BOOL checkMicrophone = NO;
    dispatch_async(dispatch_get_checking_permission_queue(), ^{
        // 检查摄像头权限
        [[self class] devicePermissionByMediaType:AVMediaTypeVideo completion:^(BOOL granted) {
            checkCamera = granted;
        }];
    });
    dispatch_async(dispatch_get_checking_permission_queue(), ^{
        // 检查麦克风权限
        [[self class] devicePermissionByMediaType:AVMediaTypeAudio completion:^(BOOL granted) {
            checkMicrophone = granted;
        }];
    });
    dispatch_async(dispatch_get_checking_permission_queue(), ^{
        if (checkCamera && checkMicrophone) {
            dispatch_async(dispatch_get_main_queue(), ^{
                CheckPermissionCompletion(YES);
            });
        } else if (!checkCamera && !checkMicrophone) {
            NSString *title = @"没有使用手机摄像头和麦克风的权限";
            NSString *message = @"请在\"[设置]-[隐私]-[摄像头/麦克风]\"里允许";
            [[self class] showAlertViewWithTitle:title message:message];
        } else if (!checkCamera) {
            NSString *title = @"没有使用手机摄像头的权限";
            NSString *message = @"请在\"[设置]-[隐私]-[摄像头]\"里允许";
            [[self class] showAlertViewWithTitle:title message:message];
        } else if (!checkMicrophone) {
            NSString *title = @"没有使用手机麦克风的权限";
            NSString *message = @"请在\"[设置]-[隐私]-[麦克风]\"里允许";
            [[self class] showAlertViewWithTitle:title message:message];
        }
    });
}

+ (void)devicePermissionByMediaType:(NSString *)mediaType completion:(void (^)(BOOL granted))completion {
    AVAuthorizationStatus  authorizationStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    if (authorizationStatus == AVAuthorizationStatusRestricted || authorizationStatus == AVAuthorizationStatusDenied) {
        completion(NO);
    } else if (authorizationStatus == AVAuthorizationStatusNotDetermined) {
        // 当用户没有授权相关权限的时候，先中断初始化操作，直到用户对请求权限进行操作才继续执行
        dispatch_suspend(dispatch_get_checking_permission_queue());
        __weak typeof(self) weakSelf = self;
        [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
            __strong typeof (self) strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            completion(granted);
            dispatch_resume(dispatch_get_checking_permission_queue());
        }];
    } else {
        completion(YES);
    }
}

+ (void)showAlertViewWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:[[self class] getInstance] cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [alertView show];
    });
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    dispatch_async(dispatch_get_main_queue(), ^{
        CheckPermissionCompletion(NO);
    });
}

#pragma mark - SVPLiveCameraDelegate

- (void)svpLiveCameraDidCaptureSpsPps:(NSData *)spsPps upVideoInfo:(NSDictionary *)videoInfo {
    if (!self.uploadEngine.videoStreamAdded) {
        [self.uploadEngine addVideoStream:videoInfo length:spsPps.length data:spsPps totalSize:0];
        self.uploadEngine.videoStreamAdded = YES;
    }
}

- (void)svpLiveCameraDidCaptureAudioHeader:(NSData *)audioHeader upAudioInfo:(NSDictionary *)audioInfo {
    if (!self.uploadEngine.audioStreamAdded) {
        [self.uploadEngine addAudioStream:audioInfo length:audioHeader.length data:audioHeader totalSize:0];
        self.uploadEngine.audioStreamAdded = YES;
    }
}

- (void)svpLiveCameraDidCaptureEncodedData:(NSData *)encodedData timestamp:(long long)timestamp isVideo:(BOOL)isVideo isKeyframe:(BOOL)isKeyframe {
    [self.uploadEngine startPushingStream:@{
                                            UPLOAD_SAMPLE_INFO_STREAM_TYPE:(isVideo?@(0):@(1)),
                                            UPLOAD_SAMPLE_INFO_IS_KEY_FRAME:(isKeyframe?@(1):@(0)),
                                            UPLOAD_SAMPLE_INFO_TIME:@(timestamp),
                                            UPLOAD_SAMPLE_INFO_CTS_DELTA:@(0),
                                            }
                                   length:encodedData.length
                                     data:encodedData
                                totalSize:0];
}

- (void)svpLiveCameraDidCaptureSessionLoadSuccess {
    NSLog(@"摄像头初始化成功");
    if (!((UIViewController *)self.delegate).view.window) {
        NSLog(@"%@已释放",NSStringFromClass(((UIViewController *)self.delegate).class));
        return;
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(svpLiveDidCaptureSessionLoadSuccess)]) {
        [self.delegate svpLiveDidCaptureSessionLoadSuccess];
    }
}

- (void)svpLiveCameraDidCaptureSessionLoadFailed:(NSUInteger)errorCode {
    NSLog(@"摄像头初始化失败，错误码：%@",@(errorCode));
}

#pragma mark - SVPLiveUploadEngineDelegate

- (void)svpLiveUploadEngineFailedWithError:(NSInteger)errorCode {
    NSLog(@"直播推流错误,错误码 ： %@",@(errorCode));
}

#pragma mark - Private

- (void)addNotificationObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self.camera.captureSession];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:self.camera.captureSession];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:self.camera.captureSession];
}

- (void)removeNotificationObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)sessionRuntimeError:(NSNotification *)notification {
    NSLog(@"session runtime error : %@",notification.userInfo[AVCaptureSessionErrorKey]);
}

- (void)sessionWasInterrupted:(NSNotification *)notification {
    NSLog(@"sessionWasInterrupted : %@",notification.userInfo);
}

- (void)sessionInterruptionEnded:(NSNotification *)notification {
    NSLog(@"sessionInterruptionEnded : %@",notification.userInfo);
}


+ (void)setCacheDuration:(NSString *)string{
    cacheDuration = string;
}

+(NSString *)getCacheDuration{
    return cacheDuration;
}

+ (void)saveLocalFile {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:SVPLiveSaveLocalFLVFile];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSArray *)getLocalFlvFiles {
    NSMutableArray *files = [NSMutableArray array];
    NSString *liveDoc = [[NSUserDefaults standardUserDefaults] objectForKey:SVPLiveOutputPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *directoryEnum = [fileManager enumeratorAtPath:liveDoc];
    NSString *file = nil;
    while (file = [directoryEnum nextObject]) {
        if ([[file pathExtension] isEqualToString:@"flv"]) {
            [files addObject:[liveDoc stringByAppendingPathComponent:file]];
        }
    }
    return files;
}

@end
