//
//  JFTAVAssetExportSession.m
//  Pods
//
//  Created by jft0m on 2017/7/19.
//
//

#import "JFTAVAssetExportSession.h"
#import "JFTAVSizeHelper.h"

float const JFTAVAssetVideoExportDefaultFrameRate = 30;
NSErrorDomain const JFTAVAssetExportErrorDomain = @"JFTAVAssetExportError";

@interface JFTAVAssetExportSession ()

@property (nonatomic, assign, readwrite) float progress;
@property (nonatomic, assign) CMTimeRange timeRangeInternal;
@property (nonatomic, strong) NSError *error;

@property (nonatomic, strong) AVAssetReader *reader;
@property (nonatomic, strong) AVAssetReaderVideoCompositionOutput *videoOutput;
@property (nonatomic, strong) AVAssetReaderAudioMixOutput *audioOutput;
@property (nonatomic, strong) AVAssetWriter *writer;
@property (nonatomic, strong) AVAssetWriterInput *videoInput;
@property (nonatomic, strong) AVAssetWriterInput *audioInput;
@property (nonatomic) dispatch_queue_t inputQueue;
@property (nonatomic, copy) void (^completionHandler)();
@property (nonatomic, strong) AVVideoComposition *videoCompositionInternal;

@property (nonatomic, copy) void(^exportingTimeStampBlock)(CMTime);

@end

@implementation JFTAVAssetExportSession
@synthesize error = _error;
+ (instancetype)exportSessionWithAsset:(AVAsset *)asset {
    return [[JFTAVAssetExportSession alloc] initWithAsset:asset];
}

- (instancetype)initWithAsset:(AVAsset *)asset {
    if (self = [super init]) {
        _asset = asset;
        _videoSettings = [JFTAVAssetExporterVideoSettings new];
        _timeRange = CMTimeRangeMake(kCMTimeZero, kCMTimeZero);
    }
    return self;
}

- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler {
    __weak typeof(self) weakSelf = self;
    self.progress = 0;
    [self loadAsset:self.asset completion:^(BOOL success, NSError *error) {
        if (success) {
            self.exportingTimeStampBlock = ^(CMTime appendTime) {
                CGFloat progress = [weakSelf calculateProgressWithTimeRange:weakSelf.timeRangeInternal
                                                         andCurrentTime:appendTime];
                if (progress >= weakSelf.progress) {
                    weakSelf.progress = progress;
//                    NSLog(@"=== progress === %f", progress);
                    if (weakSelf.exportProgressChangedBlock) {
                        weakSelf.exportProgressChangedBlock(weakSelf.progress);
                    }
                }
            };
            [self exportAsynchronouslyWithAsset:self.asset completionHandler:handler];
        } else {
            NSLog(@"【loadAsset fail】");
        }
    }];
}

- (void)loadAsset:(AVAsset *)asset completion:(void(^)(BOOL success, NSError *error))completion {
    [asset loadValuesAsynchronouslyForKeys:@[@"tracks", @"duration", @"readable"] completionHandler:^{
        AVKeyValueStatus tracksStatus = [asset statusOfValueForKey:@"tracks" error:nil];
        AVKeyValueStatus durationStatus = [asset statusOfValueForKey:@"duration" error:nil];
        AVKeyValueStatus readableStatus = [asset statusOfValueForKey:@"readable" error:nil];
        
        BOOL prepared = (tracksStatus == AVKeyValueStatusLoaded) && (durationStatus == AVKeyValueStatusLoaded)
        && (readableStatus == AVKeyValueStatusLoaded) && (asset.readable == YES);
        if (prepared) {
            completion(prepared, nil);
        } else {
            if (tracksStatus == AVKeyValueStatusFailed || durationStatus == AVKeyValueStatusFailed || readableStatus == AVKeyValueStatusFailed) {
                completion(prepared, nil);
            }
        }
    }];
}

- (void)exportAsynchronouslyWithAsset:(AVAsset *)asset
                    completionHandler:(void (^)(void))handler {
    [self cancel];
    self.completionHandler = handler;
    if (!asset || !self.outputURL) {
        self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                         code:JFTAVAssetExportResourceErrorCode
                                     userInfo:@{NSLocalizedDescriptionKey : @"asset & outputURL can't be nil"}];
        return [self complete];
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.outputURL.path]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.outputURL.path error:nil];
    }
    if (self.videoComposition) {
        self.videoCompositionInternal = self.videoComposition;
    } else {
        self.videoCompositionInternal = [self buildDefaultVideoComposition:asset];
    }
    
    if (![asset tracksWithMediaType:AVMediaTypeVideo].count) {
        self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                         code:JFTAVAssetExportResourceErrorCode
                                     userInfo:@{NSLocalizedDescriptionKey : @"asset don't have a video track"}];
        return [self complete];
    }
    
    {
        CMTime startTime, endTime;
        if (CMTimeCompare(self.timeRange.duration, kCMTimeZero) > 0) {
            startTime = self.timeRange.start;
            endTime   = CMTimeAdd(self.timeRange.start, self.timeRange.duration);
        } else {
            startTime = kCMTimeZero;
            endTime   = asset.duration;
        }
        
        if (CMTimeCompare(startTime, endTime) >= 0) {
            self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                             code:JFTAVAssetExportErrorUnknowCode
                                         userInfo:@{NSLocalizedDescriptionKey : @"startTime should less than endTime " }];
            return [self complete];
        }
        self.timeRangeInternal = CMTimeRangeMake(startTime, CMTimeSubtract(endTime, startTime));
    }
    
    /// Creating the Asset Reader
    NSError *tError;
    self.reader = [AVAssetReader assetReaderWithAsset:asset error:&tError];
    if (!self.reader) {
        self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                         code:JFTAVAssetExportErrorUnknowCode
                                     userInfo:tError.userInfo];
        return [self complete];
    }
    
    
    
    self.reader.timeRange = self.timeRangeInternal;
    NSLog(@"start %@,== duration%@", @(CMTimeGetSeconds(self.timeRangeInternal.start)), @(CMTimeGetSeconds(self.timeRangeInternal.duration)));
    /// Creating the Asset Writer
    self.writer = [AVAssetWriter assetWriterWithURL:self.outputURL
                                           fileType:AVFileTypeMPEG4
                                              error:&tError];
    if (!self.writer) {
        self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                         code:JFTAVAssetExportErrorUnknowCode
                                     userInfo:tError.userInfo];
        return [self complete];
    }
    
    // Get the audio track to read.
    if ([asset tracksWithMediaType:AVMediaTypeAudio].count) {
        // Decompression settings for Linear PCM
        // Create the output with the audio track and decompression
        self.audioOutput = [AVAssetReaderAudioMixOutput assetReaderAudioMixOutputWithAudioTracks:[asset tracksWithMediaType:AVMediaTypeAudio] audioSettings:[self readerOutputAudioSettings]];
        self.audioOutput.alwaysCopiesSampleData = NO;
        // Add the output to the reader if possible.
        if ([self.reader canAddOutput:self.audioOutput]) {
            [self.reader addOutput:self.audioOutput];
        } else {
            self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                             code:JFTAVAssetExportErrorUnknowCode
                                         userInfo:@{NSLocalizedDescriptionKey : @"JFTAVAssetExporter add audio output fail"}];
            return [self complete];
        }
        
        self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:[self writerOutputAudioSettings]];
        
        if ([self.writer canAddInput:self.audioInput]) {
            [self.writer addInput:self.audioInput];
        } else {
            
            self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                             code:JFTAVAssetExportErrorUnknowCode
                                         userInfo:@{NSLocalizedDescriptionKey : @"JFTAVAssetExporter add audio input fail" }];
            return [self complete];
        }
    }
    
    if ([asset tracksWithMediaType:AVMediaTypeVideo].count) { /// add video input and output
        self.videoOutput = [AVAssetReaderVideoCompositionOutput assetReaderVideoCompositionOutputWithVideoTracks:[asset tracksWithMediaType:AVMediaTypeVideo] videoSettings:(self.videoInputSettings?:[self decompressionVideoSettings])];
        self.videoOutput.videoComposition = self.videoCompositionInternal;
        self.videoOutput.alwaysCopiesSampleData = NO;
        if ([self.reader canAddOutput:self.videoOutput]) {
            [self.reader addOutput:self.videoOutput];
        } else {
            self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                             code:JFTAVAssetExportErrorUnknowCode
                                         userInfo:@{NSLocalizedDescriptionKey : @"JFTAVAssetExporter add video output fail"}];
            return [self complete];
        }
        
        self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                             outputSettings:[self writerOutputVideoSettingsWithSize:self.videoCompositionInternal.renderSize]];
        
        self.videoInput.expectsMediaDataInRealTime = NO;
        {
            AVAssetTrack *tTrack = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
            self.videoInput.mediaTimeScale = MIN(CMTimeMake(0, 30).timescale, tTrack.naturalTimeScale);
//            self.videoInput.transform = tTrack.preferredTransform;
        }
        
        if ([self.writer canAddInput:self.videoInput]) {
            [self.writer addInput:self.videoInput];
        } else {
            self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                             code:JFTAVAssetExportErrorUnknowCode
                                         userInfo:@{NSLocalizedDescriptionKey : @"JFTAVAssetExporter add video input fail" }];
            return [self complete];
        }
    }
    
    if (![self.reader startReading] && self.reader.status == AVAssetReaderStatusFailed) {
        self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                         code:JFTAVAssetExportErrorUnknowCode
                                     userInfo:self.reader.error.userInfo];
        return [self complete];
    }
    
    // Prepare the asset reader & writer.
    if (![self.writer startWriting] && self.writer.status == AVAssetWriterStatusFailed) {
        self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                         code:JFTAVAssetExportErrorUnknowCode
                                     userInfo:self.writer.error.userInfo];
        return [self complete];
    }
    
    [self.writer startSessionAtSourceTime:self.timeRangeInternal.start];
    
    /// Export
    
    self.inputQueue = dispatch_queue_create("com.dianping.avCompressQueue", DISPATCH_QUEUE_SERIAL);
    
    __block NSUInteger inputCount = self.writer.inputs.count;
    __block NSUInteger finishCount = 0;
    __weak typeof(self) weakSelf = self;
    
    [self.writer.inputs enumerateObjectsUsingBlock:^(AVAssetWriterInput * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        AVAssetWriterInput *input = obj;
        AVAssetReaderOutput *output;
        if ([obj.mediaType isEqualToString:AVMediaTypeVideo]) {
            output = self.videoOutput;
        } else if ([obj.mediaType isEqualToString:AVMediaTypeAudio]) {
            output = self.audioOutput;
        } else {
            self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                             code:JFTAVAssetExportErrorUnknowCode
                                         userInfo:@{NSLocalizedDescriptionKey : @"unknow input type" }];
            *stop = YES;
            [self cancel];
        }
        [obj requestMediaDataWhenReadyOnQueue:self.inputQueue usingBlock:^{
            if ([weakSelf requestMediaDataWithInput:input output:output]) {
                @synchronized (self) {
                    finishCount ++;
                    if (finishCount == inputCount) {
                        NSLog(@"weakSelf finish");
                        [weakSelf finish];
                    }
                }
            }
        }];
    }];
}

- (BOOL)requestMediaDataWithInput:(AVAssetWriterInput*)input output:(AVAssetReaderOutput *)output {
    while ([input isReadyForMoreMediaData]) {
        CMSampleBufferRef nextSampleBuffer = [output copyNextSampleBuffer];
        if (nextSampleBuffer) {
            
            BOOL appendSuccess = [input appendSampleBuffer:nextSampleBuffer];
            CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(nextSampleBuffer);
            CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDesc);
            if (mediaType == kCMMediaType_Video) {
                if (self.exportingTimeStampBlock) {
                    self.exportingTimeStampBlock(CMSampleBufferGetPresentationTimeStamp(nextSampleBuffer));
                }
            }
            
            CFRelease(nextSampleBuffer);
            nextSampleBuffer = nil;
            if (!appendSuccess) {
                NSLog(@"append fail");
                if (self.writer.status == AVAssetWriterStatusFailed) {
                    if (self.writer.error.code == 28) {
                        self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                                         code:JFTAVAssetExportNoMoreSpaceErrorCode
                                                     userInfo:self.writer.error.userInfo];
                    } else {
                        self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                                         code:JFTAVAssetExportErrorUnknowCode
                                                     userInfo:self.writer.error.userInfo];
                    }
                    NSLog(@"append fail");
                }
            }
        } else { //If sample buffer returns NULL, you should check the value of the associated AVAssetReader object’s status property to determine why no more samples could be read.
            NSLog(@"nextSampleBuffer not exit");
            if (self.reader.status == AVAssetReaderStatusFailed) {
                self.error = [NSError errorWithDomain:JFTAVAssetExportErrorDomain
                                                 code:JFTAVAssetExportErrorUnknowCode
                                             userInfo:self.reader.error.userInfo];
                return YES;
            } else {// Assume that lack of a next sample buffer means the sample buffer source is out of samples and mark the input as finished
                NSLog(@"input:%@ markAsFinished", input.mediaType);
                [input markAsFinished];
                return YES;
            }
        }
    }
    return NO;
}


#pragma mark - Life Cycle

- (void)finish
{
    if (self.reader.status == AVAssetReaderStatusCancelled || self.writer.status == AVAssetWriterStatusCancelled) return;
    
    if (self.writer.status == AVAssetWriterStatusFailed) {
        [self complete];
    } else if (self.reader.status == AVAssetReaderStatusFailed) {
        [self.writer cancelWriting];
        [self complete];
    } else if (self.error) {
        [self.videoInput markAsFinished];
        [self.audioInput markAsFinished];
        [self complete];
    }else {
        [self.videoInput markAsFinished];
        [self.audioInput markAsFinished];
        [self.writer finishWritingWithCompletionHandler:^{
            [self complete];
        }];
    }
}

- (void)cancel {
    if (self.inputQueue) {
        dispatch_async(self.inputQueue, ^{
            [self.writer cancelWriting];
            [self.reader cancelReading];
            [self complete];
            [self reset];
        });
    }
}

- (void)reset {
    self.error = nil;
    self.progress = 0;
    self.reader = nil;
    self.videoOutput = nil;
    self.audioOutput = nil;
    self.writer = nil;
    self.videoInput = nil;
    self.audioInput = nil;
    self.inputQueue = nil;
    self.completionHandler = nil;
}

- (void)complete {
    if (self.writer.status == AVAssetWriterStatusFailed || self.writer.status == AVAssetWriterStatusCancelled) {
        [NSFileManager.defaultManager removeItemAtURL:self.outputURL error:nil];
    }
    
    if (self.completionHandler) {
        self.completionHandler();
        self.completionHandler = nil;
    }
}

#pragma mark - Getter

- (AVAssetExportSessionStatus)status {
    switch (self.writer.status) {
        case AVAssetWriterStatusUnknown:
            return AVAssetExportSessionStatusUnknown;
        case AVAssetWriterStatusWriting:
            return AVAssetExportSessionStatusExporting;
        case AVAssetWriterStatusFailed:
            return AVAssetExportSessionStatusFailed;
        case AVAssetWriterStatusCompleted:
            return AVAssetExportSessionStatusCompleted;
        case AVAssetWriterStatusCancelled:
            return AVAssetExportSessionStatusCancelled;
        default:
            return AVAssetExportSessionStatusUnknown;
    }
}

- (NSError *)error {
    if (_error) {
        return _error;
    } else {
        return self.writer.error ? : self.reader.error;
    }
}

#pragma mark - Default Compositor

- (AVMutableVideoComposition *)buildDefaultVideoComposition:(AVAsset *)asset {
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    float trackFrameRate = 0;
    if (self.videoSettings) {
        trackFrameRate = self.videoSettings.nominalFrameRate;
    } else {
        trackFrameRate = [videoTrack nominalFrameRate];
    }
    
    if (trackFrameRate <= 0) trackFrameRate = JFTAVAssetVideoExportDefaultFrameRate;
    
    videoComposition.frameDuration = CMTimeMake(1, trackFrameRate);
    
    videoComposition.renderSize = videoTrack.naturalSize;
    // Make a "pass through video track" video composition.
    AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    passThroughInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
    
    AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    CGAffineTransform transform = CGAffineTransformConcat(videoTrack.preferredTransform,
                                                          [JFTAVSizeHelper scaleTransformWithTrack:videoTrack
                                                                          andRenderSize:videoComposition.renderSize]);
    
    [passThroughLayer setTransform:transform
                            atTime:kCMTimeZero];
    
    passThroughInstruction.layerInstructions = @[passThroughLayer];
    videoComposition.instructions = @[passThroughInstruction];
    return videoComposition;
}

#pragma mark - Settings
- (NSDictionary *)readerOutputAudioSettings {
    return @{ AVFormatIDKey : [NSNumber numberWithUnsignedInt:kAudioFormatLinearPCM] };
}

- (NSDictionary *)readerOutputVideoSettings {
    return @{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)};
}

- (NSDictionary *)writerOutputAudioSettings {
    // Configure the channel layout as stereo.
    AudioChannelLayout stereoChannelLayout = {
        .mChannelLayoutTag = kAudioChannelLayoutTag_Stereo,
        .mChannelBitmap = 0,
        .mNumberChannelDescriptions = 0
    };
    
    // Convert the channel layout object to an NSData object.
    NSData *channelLayoutAsData = [NSData dataWithBytes:&stereoChannelLayout length:offsetof(AudioChannelLayout, mChannelDescriptions)];
    
    // Get the compression settings for 128 kbps AAC.
    return @{
             AVFormatIDKey         : [NSNumber numberWithUnsignedInt:kAudioFormatMPEG4AAC],
             AVEncoderBitRateKey   : [NSNumber numberWithInteger:128000],
             AVSampleRateKey       : [NSNumber numberWithInteger:44100],
             AVChannelLayoutKey    : channelLayoutAsData,
             AVNumberOfChannelsKey : [NSNumber numberWithUnsignedInteger:2]
             };
    
}

- (NSDictionary *)writerOutputVideoSettingsWithSize:(CGSize)targetSize {
    NSDictionary *videoCompressionProps = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:self.videoSettings.dataBitRate * 1024],AVVideoAverageBitRateKey, nil];
    return [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecH264, AVVideoCodecKey,
            [NSNumber numberWithInt:(int)targetSize.width], AVVideoWidthKey,
            [NSNumber numberWithInt:(int)targetSize.height],AVVideoHeightKey,
            videoCompressionProps, AVVideoCompressionPropertiesKey, nil];
}

- (NSDictionary *)decompressionVideoSettings {
    return @{ (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], (id)kCVPixelBufferIOSurfacePropertiesKey : [NSDictionary dictionary] };
}

////// for debug

- (void)logTimeRange:(CMTimeRange)timeRange {
    NSLog(@"start:%f \n end:%f",CMTimeGetSeconds(timeRange.start), CMTimeGetSeconds(CMTimeAdd(timeRange.duration, timeRange.start)));
}

- (CGFloat)calculateProgressWithTimeRange:(CMTimeRange)timeRange andCurrentTime:(CMTime)currentTime {
    if (!CMTIMERANGE_IS_VALID(timeRange) || !CMTIME_IS_VALID(currentTime)) return 0;
    
    CMTime endTime = CMTimeAdd(timeRange.start, timeRange.duration);
    
    if (CMTimeCompare(endTime, currentTime) <= 0) return 1; // end time is less than current time
    
    CGFloat restTime = CMTimeGetSeconds(CMTimeSubtract(endTime, currentTime));
    return (1 - restTime / CMTimeGetSeconds(timeRange.duration));
}

- (void)setError:(NSError *)error {
    _error = error;
}

@end

@implementation JFTAVAssetExporterVideoSettings

- (instancetype)init {
    if (self = [super init]) {
        _dataBitRate = 1600;
        _preferredVideoSize = CGSizeMake(540, 960);
    }
    return self;
}

+ (instancetype)new {
    return [[JFTAVAssetExporterVideoSettings alloc] init];
}

@end
