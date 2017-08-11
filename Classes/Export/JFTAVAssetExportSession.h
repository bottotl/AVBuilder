//
//  JFTAVAssetExportSession.h
//  Pods
//
//  Created by jft0m on 2017/7/19.
//
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN
extern NSErrorDomain const JFTAVAssetExportErrorDomain;

typedef NS_ENUM(NSUInteger, JFTAVAssetExportErrorCode) {
    JFTAVAssetExportResourceErrorCode    ,
    JFTAVAssetExportNoMoreSpaceErrorCode ,
    JFTAVAssetExportErrorUnknowCode
};

@interface JFTAVAssetExporterVideoSettings : NSObject

@property (nonatomic, assign) CGFloat dataBitRate;
@property (nonatomic, assign) float nominalFrameRate;
@property (nonatomic, assign) CGSize preferredVideoSize;

@end


@interface JFTAVAssetExportSession : NSObject

+ (nullable instancetype)exportSessionWithAsset:(AVAsset *)asset;

- (nullable instancetype)initWithAsset:(AVAsset *)asset;
@property (nonatomic) CMTimeRange timeRange;

/**
 * Indicates whether video composition is enabled for export, and supplies the instructions for video composition.
 *
 * You can observe this property using key-value observing.
 */
@property (nonatomic, copy, nullable) AVVideoComposition *videoComposition;

/**
 * Indicates whether non-default audio mixing is enabled for export, and supplies the parameters for audio mixing.
 */
@property (nonatomic, copy) AVAudioMix *audioMix;

/**
 * The settings used for input video track.
 *
 * The dictionary’s keys are from <CoreVideo/CVPixelBuffer.h>.
 */
@property (nonatomic, copy) NSDictionary *videoInputSettings;

/**
 * The settings used for encoding the audio track.
 *
 * A value of nil specifies that appended output should not be re-encoded.
 * The dictionary’s keys are from <CoreVideo/CVPixelBuffer.h>.
 */
@property (nonatomic, copy) NSDictionary *audioSettings;

/**
 * The settings used for encoding the video track.
 *
 * A value of nil specifies that appended output should not be re-encoded.
 * The dictionary’s keys are from <AVFoundation/AVVideoSettings.h>.
 */
@property (nonatomic, strong) JFTAVAssetExporterVideoSettings *videoSettings;

/* Indicates the instance of AVAsset with which the AVExportSession was initialized  */
@property (nonatomic, retain, readonly) AVAsset *asset;

/* Indicates the type of file to be written by the session.
 The value of this property must be set before you invoke -exportAsynchronouslyWithCompletionHandler:; otherwise -exportAsynchronouslyWithCompletionHandler: will raise an NSInternalInconsistencyException.
 Setting the value of this property to a file type that's not among the session's supported file types will result in an NSInvalidArgumentException. See supportedFileTypes. */
@property (nonatomic, copy, nullable) NSString *outputFileType;

/* Indicates the URL of the export session's output. You may use UTTypeCopyPreferredTagWithClass(outputFileType, kUTTagClassFilenameExtension) to obtain an appropriate path extension for the outputFileType you have specified. For more information about UTTypeCopyPreferredTagWithClass and kUTTagClassFilenameExtension, on iOS see <MobileCoreServices/UTType.h> and on Mac OS X see <LaunchServices/UTType.h>.  */
@property (nonatomic, copy, nonnull) NSURL *outputURL;

/* indicates the status of the export session */
@property (nonatomic, readonly) AVAssetExportSessionStatus status;

/* describes the error that occured if the export status is AVAssetExportSessionStatusFailed */
@property (nonatomic, readonly, nullable) NSError *error;

/*!
	@method						exportAsynchronouslyWithCompletionHandler:
	@abstract					Starts the asynchronous execution of an export session.
	@param						handler
 If internal preparation for export fails, the handler will be invoked synchronously.
 The handler may also be called asynchronously after -exportAsynchronouslyWithCompletionHandler: returns,
 in the following cases:
 1) if a failure occurs during the export, including failures of loading, re-encoding, or writing media data to the output,
 2) if -cancelExport is invoked,
 3) if export session succeeds, having completely written its output to the outputURL.
 In each case, AVAssetExportSession.status will signal the terminal state of the asset reader, and if a failure occurs, the NSError
 that describes the failure can be obtained from the error property.
	@discussion					Initiates an asynchronous export operation and returns immediately.
 */
- (void)exportAsynchronouslyWithCompletionHandler:(void (^)(void))handler;

/* Specifies the progress of the export on a scale from 0 to 1.0.  A value of 0 means the export has not yet begun, A value of 1.0 means the export is complete. This property is not key-value observable. */
@property (nonatomic, readonly) float progress;

/*!
	@method						cancel
	@abstract					Cancels the execution of an export session.
	@discussion					Cancel can be invoked when the export is running.
 */
- (void)cancel;

@property (nonatomic, copy) void(^exportProgressChangedBlock)(CGFloat);

@end

NS_ASSUME_NONNULL_END
