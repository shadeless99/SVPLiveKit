//
//  UIImage+Resize.h
//  DemoLiveStreaming
//
//  Created by yongqingguo on 16/5/9.
//  Copyright © 2016年 gyq. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMedia/CMSampleBuffer.h>

@interface UIImage (Resize)

@property (nonatomic,assign) CGRect watermask_frame; // 作为水印图，在背景图上的frame
@property (nonatomic,assign) CGRect parent_frame; // 背景图frame
@property (nonatomic,copy) NSString *watermarkStyle; // 水印样式

/**
 *  将图片裁剪到对应的尺寸
 *
 *  @param size 要裁剪的尺寸
 *
 *  @return 返回UIImage对象
 */
- (instancetype)resizeToSize:(CGSize)size;

/**
 将CMSampleBufferRef转化成UIImage

 @param sampleBuffer 采集到的每一帧数据
 @return 返回转换后的UIImage对象
 */
+ (UIImage *)imageWithSampleBuffer:(CMSampleBufferRef)sampleBuffer;

/**
 将UIImage转化为CVPixelBufferRef

 @param img UIImage对象
 @return 返回转换后的CVPixelBufferRef
 */
+ (CVPixelBufferRef)pixelBufferRefFromImage:(UIImage *)img;

#pragma mark - 水印合成

/**
 批量合成带水印图片（GPU处理）
 
 @param maskImages 水印图集
 @return 返回合成后的UIImage对象
 */
- (instancetype)imageWithWatermasksByGPUWithMaskImages:(NSArray *)maskImages;

/**
 单张合成带水印图片（CPU处理）
 
 @param sourceImg 背景图
 @param maskImg 水印图
 @return 返回合成后的UIImage对象
 */
+ (instancetype)watermaskImageByCPUWithSource:(UIImage *)sourceImg mask:(UIImage *)maskImg;

// 快捷方法
+ (instancetype)watermaskedBuffer:(CMSampleBufferRef)sampleBuffer maskImages:(NSArray *)maskImages;

@end
