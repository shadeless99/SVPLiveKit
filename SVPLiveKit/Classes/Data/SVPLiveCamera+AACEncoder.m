//
//  SVPLiveCamera+AACEncoder.m
//  DemoLiveStreaming
//
//  Created by yongqingguo on 16/4/29.
//  Copyright © 2016年 gyq. All rights reserved.
//

#import "SVPLiveCamera+AACEncoder.h"
#import <objc/runtime.h>

static char *aacEncoderKey = "aacEncoderKey";
static char *audioHeaderKey = "audioHeaderKey";

@interface SVPAACEncoder()
{
    AudioConverterRef _converter;
    dispatch_queue_t aQueue;
    char _pcm_pool[4096];  //单声道，16bit ，1024个sample = 2048 个字节。 做为缓存，再大一些，4096
    int _pcm_pool_sample;
}

@end

@implementation SVPAACEncoder

#pragma mark - Private

/**
 *  根据输入样本初始化一个编码转换器
 *
 *  @param sampleBuffer 音频输入样本
 *
 *  @return <#return value description#>
 */
- (BOOL)createAudioConvert:(CMSampleBufferRef)sampleBuffer {
    if (_converter != nil) {
        return YES;
    }
    // 输入音频格式
    AudioStreamBasicDescription inputFormat = *(CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sampleBuffer)));
    // 输出音频格式
    AudioStreamBasicDescription outputFormat;
    memset(&outputFormat, 0, sizeof(outputFormat));
    // 采样率保持一致
    outputFormat.mSampleRate = inputFormat.mSampleRate;
    // AAC编码
    outputFormat.mFormatID = kAudioFormatMPEG4AAC;
    // 单声道
    outputFormat.mChannelsPerFrame = 1;
    // AAC一帧是1024字节
    outputFormat.mFramesPerPacket = 1024;
    // 软编码（据说硬编码会有延迟）
    AudioClassDescription *desc = [self getAudioClassDescriptionWithType:kAudioFormatMPEG4AAC fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    if (AudioConverterNewSpecific(&inputFormat, &outputFormat, 1, desc, &_converter) != noErr) {
        NSLog(@"AudioConverterNewSpecific failed");
        return NO;
    }
    return YES;
}

/**
 *  获得相应的编码器
 *
 *  @param type         <#type description#>
 *  @param manufacturer <#manufacturer description#>
 *
 *  @return <#return value description#>
 */
- (AudioClassDescription *)getAudioClassDescriptionWithType:(UInt32)type fromManufacturer:(UInt32)manufacturer {
    static AudioClassDescription audioDesc;
    UInt32 encoderSpecifier = type, size = 0;
    OSStatus status;
    memset(&audioDesc, 0, sizeof(audioDesc));
    status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size);
    if (status) {
        return nil;
    }
    uint32_t count = size / sizeof(AudioClassDescription);
    AudioClassDescription descs[count];
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size, descs);
    for (uint32_t i = 0; i < count; i++) {
        if ((type == descs[i].mSubType) && (manufacturer == descs[i].mManufacturer)) {
            memcpy(&audioDesc, &descs[i], sizeof(audioDesc));
            break;
        }
    }
    return &audioDesc;
}

// AudioConverterFillComplexBuffer编码过程中，会要求这个函数来填充输入数据，也就是原始PCM数据
OSStatus inputDataProc(AudioConverterRef inConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData,AudioStreamPacketDescription **outDataPacketDescription, void *inUserData) {
    char * inBuffer = (char *)inUserData;
    ioData->mBuffers[0].mNumberChannels = 1;
    ioData->mBuffers[0].mData = inBuffer;
    ioData->mBuffers[0].mDataByteSize = 2048;
    *ioNumberDataPackets = 1024;
    return noErr;
}

#pragma mark - Public

- (instancetype)init {
    self = [super init];
    if (self) {
        aQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        _pcm_pool_sample=0;
    }
    return self;
}

- (BOOL)encodeBuffer:(char *)inBuff {
    // 初始化一个输出缓冲列表
    AudioBufferList outBufferList = {0};
    outBufferList.mNumberBuffers = 1;
    
    char szBuf[2048];
    int nSize = sizeof(szBuf);
    
    // 设置为单声道
    outBufferList.mBuffers[0].mNumberChannels = 1;
    //    // 设置缓冲区大小
    outBufferList.mBuffers[0].mDataByteSize = nSize;
    //    // 设置AAC缓冲区
    outBufferList.mBuffers[0].mData = szBuf;
    UInt32 outputDataPacketSize = 1;
    OSStatus statusCode = AudioConverterFillComplexBuffer(_converter, inputDataProc, inBuff, &outputDataPacketSize, &outBufferList, NULL);
    if (statusCode != noErr) {
        NSLog(@"status Code : %@",@(statusCode));
        NSLog(@"m_converter : %p",_converter);
        NSLog(@"AudioConverterFillComplexBuffer failed");
        return NO;
    }
    
    NSData *encodedData = [[NSData alloc] initWithBytes:outBufferList.mBuffers[0].mData length:outBufferList.mBuffers[0].mDataByteSize];
    if (self.delegate && [self.delegate respondsToSelector:@selector(gotEncodedData:)]) {
        [self.delegate gotEncodedData:encodedData];
    } else {
        NSLog(@"编码失败！！！");
        return NO;
    }
    return YES;
}

- (BOOL)encodeAAC:(CMSampleBufferRef)sampleBuffer {
    __block BOOL encodeResult = false;
    __weak typeof (self) weakSelf = self;
    dispatch_sync(aQueue, ^{
        __strong typeof (self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if ([strongSelf createAudioConvert:sampleBuffer] != YES) {
            return;
        }
        CMBlockBufferRef blockBuffer = nil;
        // 初始化一个输入缓冲列表
        AudioBufferList inBufferList = {0};
        if (CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &inBufferList, sizeof(inBufferList), NULL, NULL, 0, &blockBuffer) != noErr) {
            NSLog(@"CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer failed");
            return;
        }
        
        char inBuff[2048];
        UInt32 SampleCount = inBufferList.mBuffers[0].mDataByteSize / 2;
        UInt32 TotalSampleCount = strongSelf->_pcm_pool_sample + SampleCount;
        if (TotalSampleCount < 1024) {
            memcpy(strongSelf->_pcm_pool + strongSelf->_pcm_pool_sample * 2, inBufferList.mBuffers[0].mData, SampleCount * 2);
            strongSelf->_pcm_pool_sample = TotalSampleCount;
            CFRelease(blockBuffer);
            return;
        } else {
            if (strongSelf->_pcm_pool_sample > 0) {
                memcpy(inBuff, strongSelf->_pcm_pool, strongSelf->_pcm_pool_sample * 2);
            }
            memcpy(inBuff + strongSelf->_pcm_pool_sample * 2, inBufferList.mBuffers[0].mData, 2048 - strongSelf->_pcm_pool_sample * 2);
            [strongSelf encodeBuffer:inBuff];
            
            UInt32 loopCount = 0;
            UInt32 LeftSampleCount = TotalSampleCount - 1024;
            while (LeftSampleCount > 1024) {
                memcpy(inBuff, inBufferList.mBuffers[0].mData + (2048 - strongSelf->_pcm_pool_sample * 2) + loopCount * 2048, 2048);
                [strongSelf encodeBuffer:inBuff];
                LeftSampleCount -= 1024;
                loopCount ++;
            }
            if (LeftSampleCount > 0) {
                memcpy(strongSelf->_pcm_pool,inBufferList.mBuffers[0].mData + (2048 - strongSelf->_pcm_pool_sample * 2) + loopCount * 2048,LeftSampleCount * 2);
            }
            strongSelf->_pcm_pool_sample = LeftSampleCount;
        }
        CFRelease(blockBuffer);
        encodeResult = true;
    });
    return encodeResult;
}

@end

@implementation SVPLiveCamera (AACEncoder)

#pragma mark - Private

#pragma  - Private

int GetObjectType(const char * p_extra,int extraLen) {
    if ( extraLen >= 1 ) {
        char type = p_extra[0] >> 3;
        if (type == 31) {
            type = 32 + (p_extra[0] >> 2);
        }
        if ( type == 5 ) {//SBR (Spectral Band Replication)
            type = 2; //HE = LC + SBR
        }
        //profile, the MPEG-4 Audio Object Type minus 1
        return type - 1;
    } else {
        return 0;
    }
}

//void getAdtsHeader(const char* codec, int extraLen, char* bits, int frame_size)
//{
//    const char* p_extra = codec;
//    if( extraLen < 2 || !p_extra )
//        return ; /* no data to construct the headers */
//    int i_index = ( (p_extra[0] << 1) | (p_extra[1] >> 7) ) & 0x0f;
//    int i_profile = GetObjectType(p_extra, extraLen); /* i_profile < 4 */
//
//    if( i_index == 0x0f && extraLen < 5 )
//        return ; /* not enough data */
//    int i_channels = (p_extra[i_index == 0x0f ? 4 : 1] >> 3) & 0x0f;
//
//    DLog(@"da: i_index:%d i_profile:%d i_channels:%d",i_index, i_profile, i_channels);
//
//    /* fixed header */
//    bits[0] = 0xff;
//    bits[1] = 0xf1; /* 0xf0 | 0x00 | 0x00 | 0x01 */
//    bits[2] = (i_profile << 6) | ((i_index & 0x0f) << 2) | ((i_channels >> 2) & 0x01) ;
//    bits[3] = (i_channels << 6) | (((frame_size + 7)>> 11) & 0x03);
//    /* variable header (starts at last 2 bits of 4th byte) */
//    int i_fullness = 0x7ff; /* 0x7ff means VBR */
//    /* XXX: We should check if it's CBR or VBR, but no known implementation
//     * do that, and it's a pain to calculate this field */
//    bits[4] = (frame_size + 7) >> 3;
//    bits[5] = (((frame_size + 7) & 0x07) << 5) | ((i_fullness >> 6) & 0x1f);
//    bits[6] = ((i_fullness & 0x3f) << 2) /* | 0xfc */;
//}

void getAdtsHeaderEx(
                     char bits[7],
                     int frame_size,
                     int sampling_frequency_index,
                     int channel_configuration)
{
    bits[0] = 0xFF;
    bits[1] = 0xF1; // 0xF9 (MPEG2)
    bits[2] = 0x40 | (sampling_frequency_index << 2) | (channel_configuration >> 2);
    bits[3] = ((channel_configuration&0x3)<<6) | ((frame_size+7) >> 11);
    bits[4] = ((frame_size+7) >> 3)&0xFF;
    bits[5] = (((frame_size+7) << 5)&0xFF) | 0x1F;
    bits[6] = 0xFC;
}

#pragma mark - Public

- (void)initAACEncoder {
    self.aacEncoder = [[SVPAACEncoder alloc] init];
}

- (SVPAACEncoder *)aacEncoder {
    return objc_getAssociatedObject(self, aacEncoderKey);
}

- (void)setAacEncoder:(SVPAACEncoder *)aacEncoder {
    objc_setAssociatedObject(self, aacEncoderKey, aacEncoder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSData *)audioHeader {
    return objc_getAssociatedObject(self, audioHeaderKey);
}

- (void)setAudioHeader:(NSData *)audioHeader {
    objc_setAssociatedObject(self, audioHeaderKey, audioHeader, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)encodeAAC:(CMSampleBufferRef)sampleBuffer {
    return [self.aacEncoder encodeAAC:sampleBuffer];
}

#pragma mark - SVPAACEncoderDelegate

- (void)gotEncodedData:(NSData *)data {
    NSLog(@"got audio data : %@",@(data.length));
    if (self.isFirstAudioSampleBuffer) {
        self.audioHeader = data;
        char *outPrint = (char *)self.audioHeader.bytes;
        NSLog(@"da: %02x %02x %02x %02x",outPrint[0],outPrint[1],outPrint[2],outPrint[3]);
        if (self.delegate && [self.delegate respondsToSelector:@selector(svpLiveCameraDidCaptureAudioHeader:upAudioInfo:)]) {
            [self.delegate svpLiveCameraDidCaptureAudioHeader:nil upAudioInfo:@{UPLOAD_INFO_TIMESCALE:@(TIME_SCALE),
                                                                                UPLOAD_INFO_BITRATE:@(DEFAULT_BIT_RATE),
                                                                                UPLOAD_AUDIO_INFO_CHANNEL_COUNT:@(1),
                                                                                UPLOAD_AUDIO_INFO_SAMPLE_SIZE:@(16),
                                                                                 UPLOAD_AUDIO_INFO_SAMPLE_RATE:@(44100)}];
        }
    } else {
        char adts[7];
        //        char* outPrint = (char*)da.bytes;
        //DLog(@"da: %02x %02x %02x %02x",outPrint[0],outPrint[1],outPrint[2],outPrint[3]);
        
        //getAdtsHeader(da.bytes, da.length, adts,data.length);
        getAdtsHeaderEx(adts,data.length, 4, 1);
        [self.aacFileHandler writeData:[[NSData alloc] initWithBytes:adts length:7]];
        [self.aacFileHandler writeData:data];
        
        long long time = [[NSString stringWithFormat:@"%.f",([[NSDate date] timeIntervalSince1970] - self.originTimestamp) * 1000] longLongValue];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(svpLiveCameraDidCaptureEncodedData:timestamp:isVideo:isKeyframe:)]) {
            [self.delegate svpLiveCameraDidCaptureEncodedData:data timestamp:time isVideo:NO isKeyframe:NO];
        }
    }
}

@end
