//
//  H264HwEncoderImpl.m
//  h264v1
//
//  Created by Ganvir, Manish on 3/31/15.
//  Copyright (c) 2015 Ganvir, Manish. All rights reserved.
//

#import "H264HwEncoderImpl.h"
#import "SVPLiveConfiguration.h"
#define YUV_FRAME_SIZE 2000
#define FRAME_WIDTH
#define NUMBEROFRAMES 300
#define DURATION 12

#define FPS 20

@import VideoToolbox;
@import AVFoundation;

@implementation H264HwEncoderImpl
{
    NSString * yuvFile;
    VTCompressionSessionRef EncodingSession;
    dispatch_queue_t aQueue;
    CMFormatDescriptionRef  format;
    CMSampleTimingInfo *timingInfo;
    BOOL initialized;
    int  frameCount;
    NSData *sps;
    NSData *pps;
}
@synthesize error;

- (void)dealloc {
    dispatch_sync(aQueue, ^{
        [self End];
    });
}

- (void)initWithConfiguration {
    initialized = true;
    aQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    frameCount = 0;
    sps = NULL;
    pps = NULL;
}

void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer) {
    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) return;
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    H264HwEncoderImpl *encoder = (__bridge H264HwEncoderImpl *)outputCallbackRefCon;
    
    // Check if we have got a key frame first
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    if (keyframe) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        // CFDictionaryRef extensionDict = CMFormatDescriptionGetExtensions(format);
        // Get the extensions
        // From the extensions get the dictionary with key "SampleDescriptionExtensionAtoms"
        // From the dict, get the value for the key "avcC"
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        if (statusCode == noErr) {
            // Found sps and now check for pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr) {
                // Found pps
                encoder->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                encoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if (encoder->_delegate)
                {
                    [encoder->_delegate gotSpsPps:encoder->sps pps:encoder->pps];
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // Convert the length value from Big-endian to Little-endian
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder->_delegate gotEncodedData:data isKeyFrame:keyframe];
            
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
        
    }
    
}

#pragma mark initEncode_here

- (void)initEncode:(int)width height:(int)height bitrate:(NSInteger)bitrate {
    __weak typeof (self) weakSelf = self;
    dispatch_sync(aQueue, ^{
        __strong typeof (self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        // For testing out the logic, lets read from a file and then send it to encoder to create h264 stream
        
        // Create the compression session
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self),  &strongSelf->EncodingSession);
        NSLog(@"H264: VTCompressionSessionCreate %d", (int)status);
        
        if (status != 0) {
            NSLog(@"H264: Unable to create a H264 session");
            strongSelf.error = @"H264: Unable to create a H264 session";
            return;
        }
        
        VTSessionSetProperty(strongSelf->EncodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        
        VTSessionSetProperty(strongSelf->EncodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)(@(FRAME_RATE_HIGH)));
        VTSessionSetProperty(strongSelf->EncodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)(@(FRAME_RATE_HIGH)));
        
        VTSessionSetProperty(strongSelf->EncodingSession, kVTCompressionPropertyKey_Quality, (__bridge CFTypeRef)(@(1.00)));
        
        
        VTSessionSetProperty(strongSelf->EncodingSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)(@(bitrate)));
        VTSessionSetProperty(strongSelf->EncodingSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)(@[@(bitrate*6 / 5/ 8), @(1)]));
        
        VTSessionSetProperty(strongSelf->EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
        
        //VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
        
        VTSessionSetProperty(strongSelf->EncodingSession , kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanTrue);
        
        // Tell the encoder to start encoding
        VTCompressionSessionPrepareToEncodeFrames(strongSelf->EncodingSession);
    });
}

#pragma mark encode_here

- (void)encode:(CMSampleBufferRef)sampleBuffer {
    if (aQueue == nil) {
        return;
    }
    __weak typeof (self) weakSelf = self;
    dispatch_sync(aQueue, ^{
        __strong typeof (self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf->frameCount ++;
        // Get the CV Image buffer
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        
        // Create properties
        CMTime presentationTimeStamp = CMTimeMake(strongSelf->frameCount * FRAME_DURATION, 1000);
        CMTime duration = CMTimeMake(FRAME_DURATION, 1000);
        
        VTEncodeInfoFlags flags;
        if (!strongSelf->EncodingSession){
            return;
        }
        // Pass it to the encoder
        OSStatus statusCode = VTCompressionSessionEncodeFrame(strongSelf->EncodingSession,
                                                              imageBuffer,
                                                              presentationTimeStamp,
                                                              //kCMTimeInvalid,
                                                              duration,
                                                              NULL, NULL, &flags);
        // Check for error
        if (statusCode != noErr) {
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            strongSelf.error = @"H264: VTCompressionSessionEncodeFrame failed ";
            
            // End the session
            if (strongSelf->EncodingSession) {
                @synchronized (strongSelf) {
                    if (strongSelf->EncodingSession) {
                        VTCompressionSessionInvalidate(strongSelf->EncodingSession);
                        CFRelease(strongSelf->EncodingSession);
                        strongSelf->EncodingSession = NULL;
                        strongSelf.error = NULL;
                    }
                }
            }
            return;
        }
        NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
    });
}

- (void)encodePixel:(CVPixelBufferRef)pixelBuffer {
    if (aQueue == nil) {
        return;
    }
    __weak typeof (self) weakSelf = self;
    dispatch_sync(aQueue, ^{
        __strong typeof (self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        strongSelf->frameCount ++;
        // Get the CV Image buffer
        CVImageBufferRef imageBuffer = pixelBuffer;
        
        // Create properties
        CMTime presentationTimeStamp = CMTimeMake(strongSelf->frameCount * FRAME_DURATION, 1000);
        CMTime duration = CMTimeMake(FRAME_DURATION, 1000);
        
        VTEncodeInfoFlags flags;
        if(!strongSelf->EncodingSession){
            return;
        }
        // Pass it to the encoder
        OSStatus statusCode = VTCompressionSessionEncodeFrame(strongSelf->EncodingSession,
                                                              imageBuffer,
                                                              presentationTimeStamp,
                                                              //kCMTimeInvalid,
                                                              duration,
                                                              NULL, NULL, &flags);
        CVPixelBufferRelease(pixelBuffer);
        // Check for error
        if (statusCode != noErr) {
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            strongSelf.error = @"H264: VTCompressionSessionEncodeFrame failed ";
            
            // End the session
            if (strongSelf->EncodingSession) {
                @synchronized (strongSelf) {
                    if (strongSelf->EncodingSession) {
                        VTCompressionSessionInvalidate(strongSelf->EncodingSession);
                        CFRelease(strongSelf->EncodingSession);
                        strongSelf->EncodingSession = NULL;
                        strongSelf.error = NULL;
                    }
                }
            }
            return;
        }
        NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
    });
}

- (void)End {
    // Mark the completion
    VTCompressionSessionCompleteFrames(EncodingSession, kCMTimeInvalid);
    
    // End the session
    if (EncodingSession) {
        @synchronized (self) {
            if (EncodingSession) {
                VTCompressionSessionInvalidate(EncodingSession);
                CFRelease(EncodingSession);
                EncodingSession = NULL;
                error = NULL;
            }
        }
    }
    error = NULL;
}

@end
