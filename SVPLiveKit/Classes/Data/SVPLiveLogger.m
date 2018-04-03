//
//  SVPLiveLogger.m
//  svpsdk
//
//  Created by yongqingguo on 2017/3/31.
//  Copyright © 2017年 vd. All rights reserved.
//

#import "SVPLiveLogger.h"
#import <UIKit/UIKit.h>
#import "sys/utsname.h"

// sdk 版本
#define SVPLiveSDKVersion   @"1.0.0"

@interface SVPLiveLogger()
{
    NSFileManager *_fileManager;
    NSFileHandle *_fileHandler;
    NSString *_logFilePath;
}

@end

@implementation SVPLiveLogger

- (void)dealloc {
    [_fileHandler closeFile];
    _fileHandler = NULL;
}

static SVPLiveLogger *logger = nil;
+ (instancetype)getInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logger = [[SVPLiveLogger alloc] init];
    });
    return logger;
}

+ (void)destroyInstance {
    logger = nil;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *logDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Log"];
        
        _fileManager = [NSFileManager defaultManager];
        BOOL fileExists = [_fileManager fileExistsAtPath:logDirectory];
        if (!fileExists) {
            [_fileManager createDirectoryAtPath:logDirectory  withIntermediateDirectories:YES attributes:nil error:nil];
        }
        [self handleFilesOfDirectory:logDirectory];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"]; // 每次启动后都保存一个新的日志文件中
        NSString *dateStr = [formatter stringFromDate:[NSDate date]];
        _logFilePath = [logDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.log",dateStr]];
        
        [_fileManager createFileAtPath:_logFilePath contents:nil attributes:nil];
        
        _fileHandler = [NSFileHandle fileHandleForWritingAtPath:_logFilePath];
        
        struct utsname systemInfo;
        uname(&systemInfo);
        NSString *platform = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
        NSData *systemData = [[NSString stringWithFormat:@"SDKVersion:%@\n设备名称:%@\n手机系统版本:%@\n应用版本号:%@\n\n",SVPLiveSDKVersion,platform,[[UIDevice currentDevice] systemVersion],[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]] dataUsingEncoding:NSUTF8StringEncoding];
        [_fileHandler writeData:systemData];
    }
    return self;
}

/**
 处理文件夹中的文件，如果多余十条则删除最旧的一条

 @param directory 文件夹路径
 */
- (void)handleFilesOfDirectory:(NSString *)directory {
    NSMutableArray *files = [NSMutableArray array];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *directoryEnum = [fileManager enumeratorAtPath:directory];
    NSString *file = nil;
    while (file = [directoryEnum nextObject]) {
        if ([[file pathExtension] isEqualToString:@"log"]) {
            [files addObject:[directory stringByAppendingPathComponent:file]];
        }
    }
    if (files.count >= 10) {
        [fileManager removeItemAtPath:files[0] error:nil];
    }
}

- (void)log:(NSString *)msg {
    // 将log输入到文件
    NSLog(@"%@",msg);
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    NSString *dateStr = [formatter stringFromDate:[NSDate date]];
    NSData *msgData = [[[NSString stringWithFormat:@"%@ ",dateStr] stringByAppendingString:[NSString stringWithFormat:@" %@\n",msg]] dataUsingEncoding:NSUTF8StringEncoding];
    [_fileHandler writeData:msgData];
}

- (void)error:(NSString *)msg file:(const char *)file line:(int)line {
    // 将log输入到文件
    NSLog(@"%@",msg);
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    NSString *dateStr = [formatter stringFromDate:[NSDate date]];
    NSData *msgData = [[[NSString stringWithFormat:@"\n[error!] %@(line:%d)\n%@ ",[[NSString stringWithUTF8String:file] lastPathComponent],line,dateStr] stringByAppendingString:[NSString stringWithFormat:@" %@\n\n",msg]] dataUsingEncoding:NSUTF8StringEncoding];
    [_fileHandler writeData:msgData];
}

@end
