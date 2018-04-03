//
//  SVPLiveLogger.h
//  svpsdk
//
//  Created by yongqingguo on 2017/3/31.
//  Copyright © 2017年 vd. All rights reserved.
//

#import <Foundation/Foundation.h>

#define log_error(msg) [[SVPLiveLogger getInstance] error:msg file:__FILE__ line:__LINE__]

/**
 日志记录工具
 */
@interface SVPLiveLogger : NSObject

+ (instancetype)getInstance;

+ (void)destroyInstance;

/**
 记录到日志文件

 @param msg 日志内容
 */
- (void)log:(NSString *)msg;

/**
 记录请求错误到日志文件
 
 @param msg 日志内容
 */
- (void)error:(NSString *)msg file:(const char *)file line:(int)line;

@end
