//
//  UIImage+Resize.m
//  DemoLiveStreaming
//
//  Created by yongqingguo on 16/5/9.
//  Copyright © 2016年 gyq. All rights reserved.
//

#import "UIImage+Resize.h"
#import <objc/runtime.h>

const char * SVPLIVE_WATERMASK_FRAME_KEY = &SVPLIVE_WATERMASK_FRAME_KEY;
const char * SVPLIVE_PARENT_FRAME_KEY = &SVPLIVE_PARENT_FRAME_KEY;
const char * SVPLIVE_WATERMARK_STYLE_KEY = &SVPLIVE_WATERMARK_STYLE_KEY;

@implementation UIImage (Resize)

- (NSString *)watermarkStyle {
    NSString *style = objc_getAssociatedObject(self, SVPLIVE_WATERMARK_STYLE_KEY);
    if ([style isEqualToString:@"h"]) {
        return @"h";
    } else if ([style isEqualToString:@"v"]) {
        return @"v";
    } else if ([style isEqualToString:@"l1"]) {
        return @"l1";
    } else if ([style isEqualToString:@"l2"]) {
        return @"l2";
    } else return @"";
}

- (void)setWatermarkStyle:(NSString *)watermarkStyle {
    objc_setAssociatedObject(self, SVPLIVE_WATERMARK_STYLE_KEY, watermarkStyle, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (CGRect)watermask_frame {
    NSValue *location = objc_getAssociatedObject(self, SVPLIVE_WATERMASK_FRAME_KEY);
    if (!location) {
        return CGRectMake(0, 0, self.size.width, self.size.height);
    }
    CGRect locationRec = location.CGRectValue;
    CGFloat ratioX = [UIScreen mainScreen].bounds.size.width / self.parent_frame.size.width;
    CGFloat ratioY = [UIScreen mainScreen].bounds.size.height / self.parent_frame.size.height;
    CGRect newRec = CGRectMake(locationRec.origin.x / ratioX, self.parent_frame.size.height - locationRec.size.height / ratioY - locationRec.origin.y / ratioY, locationRec.size.width / ratioX, locationRec.size.height / ratioY);
    return newRec;
}

- (void)setWatermask_frame:(CGRect)watermask_frame {
    objc_setAssociatedObject(self, SVPLIVE_WATERMASK_FRAME_KEY, [NSValue valueWithCGRect:watermask_frame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGRect)parent_frame {
    NSValue *parentFrame = objc_getAssociatedObject(self, SVPLIVE_PARENT_FRAME_KEY);
    return parentFrame.CGRectValue;
}

- (void)setParent_frame:(CGRect)parent_frame {
    objc_setAssociatedObject(self, SVPLIVE_PARENT_FRAME_KEY, [NSValue valueWithCGRect:parent_frame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (instancetype)resizeToSize:(CGSize)size {
    UIGraphicsBeginImageContext(size);
    [self drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

+ (UIImage *)imageWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    // 为媒体数据设置一个CMSampleBuffer的Core Video图像缓存对象
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // 锁定pixel buffer的基地址
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // 得到pixel buffer的基地址
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // 得到pixel buffer的行字节数
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // 得到pixel buffer的宽和高
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    // 创建一个依赖于设备的RGB颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // 用抽样缓存的数据创建一个位图格式的图形上下文（graphics context）对象
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // 根据这个位图context中的像素数据创建一个Quartz image对象
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // 解锁pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // 释放context和颜色空间
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // 用Quartz image创建一个UIImage对象image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // 释放Quartz image对象
    CGImageRelease(quartzImage);
    
    return (image);
}

+ (CVPixelBufferRef)pixelBufferRefFromImage:(UIImage *)img {
    CGSize size = img.size;
    CGImageRef image = [img CGImage];
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options, &pxbuffer);
    
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, size.width, size.height, 8, 4 * size.width, rgbColorSpace, kCGImageAlphaPremultipliedFirst);
    NSParameterAssert(context);
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
    
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

- (instancetype)imageWithWatermasksByGPUWithMaskImages:(NSArray *)maskImages {
    if (maskImages && maskImages.count > 0) {
        __weak typeof (self) weakSelf = self;
        CIImage *sourCIImage = [[CIImage alloc] initWithImage:weakSelf];
        CIImage *maskCIImage = nil;
        CIFilter *blendFilter = [CIFilter filterWithName:@"CISourceAtopCompositing"];
        for (int i = 0; i < maskImages.count; i ++) {
            UIImage *img = maskImages[i];
            img.parent_frame = CGRectMake(0, 0, weakSelf.size.width, weakSelf.size.height);
            maskCIImage = [[CIImage alloc] initWithImage:img];
            // 裁剪水印尺寸
            if (!CGSizeEqualToSize(img.size, img.watermask_frame.size)) {
                CGFloat ratioX = img.watermask_frame.size.width / img.size.width;
                CGFloat ratioY = img.watermask_frame.size.height / img.size.height;
                maskCIImage = [maskCIImage imageByApplyingTransform:CGAffineTransformMakeScale(ratioX, ratioY)];
            }
            // 调整水印位置
            maskCIImage = [maskCIImage imageByApplyingTransform:CGAffineTransformMakeTranslation(img.watermask_frame.origin.x, img.watermask_frame.origin.y)];
            // 合并图片
            [blendFilter setValue:sourCIImage forKeyPath:@"inputBackgroundImage"];
            [blendFilter setValue:maskCIImage forKeyPath:@"inputImage"];
            sourCIImage = [blendFilter outputImage];
        }
        // Render output image
        CIContext *context = [CIContext contextWithOptions:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:kCIContextUseSoftwareRenderer]]; // GPU渲染
        CGImageRef outputCGImage = [context createCGImage:sourCIImage fromRect:[sourCIImage extent]];
        UIImage *outputImage = [UIImage imageWithCGImage:outputCGImage];
        CGImageRelease(outputCGImage);
        return outputImage;
    }
    return self;
}

+ (instancetype)watermaskImageByCPUWithSource:(UIImage *)sourceImg mask:(UIImage *)maskImg {
    CGFloat sourceWidth = sourceImg.size.width;
    CGFloat sourceHeight = sourceImg.size.height;
    CGFloat maskWidth = maskImg.size.width;
    CGFloat maskHeight = maskImg.size.height;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, sourceWidth, sourceHeight, 8, 0, colorSpace, kCGImageAlphaPremultipliedFirst);
    CGContextDrawImage(context, CGRectMake(0, 0, sourceWidth, sourceHeight), sourceImg.CGImage);
    CGContextDrawImage(context, CGRectMake(sourceWidth - maskWidth, 0, maskWidth, maskHeight), [maskImg CGImage]);
    CGImageRef imageMasked = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    UIImage *img = [UIImage imageWithCGImage:imageMasked];
    CGImageRelease(imageMasked);
    return img;
}

+ (instancetype)watermaskedBuffer:(CMSampleBufferRef)sampleBuffer maskImages:(NSArray *)maskImages {
    UIImage *sourceImg = [[self class] imageWithSampleBuffer:sampleBuffer];
    if (maskImages && maskImages.count > 0) {
        UIImage *blendImg = [sourceImg imageWithWatermasksByGPUWithMaskImages:maskImages];
        return blendImg;
    } else {
        return sourceImg;
    }
}

@end
