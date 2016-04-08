//
//  ViewController.m
//  WormVideoSizeTest
//
//  Created by Petr Pavlik on 08/04/16.
//  Copyright © 2016 Worm. All rights reserved.
//

#import "ViewController.h"
#import "SDAVAssetExportSession.h"

@import Photos;
@import AssetsLibrary;

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self processVideo];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)processVideo {
    
    NSURL *assetURL = [[[NSBundle mainBundle] resourceURL] URLByAppendingPathComponent:@"240fps-orig.MOV"];
    
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:assetURL.path error:nil];
    NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
    NSString *originalSize = [NSByteCountFormatter stringFromByteCount:fileSizeNumber.longLongValue countStyle:NSByteCountFormatterCountStyleFile];
    
    AVAsset *asset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
    
    AVAssetTrack * videoATrack = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    NSParameterAssert(videoATrack);
    
    CGFloat videoFPS = videoATrack.nominalFrameRate;
    
    SDAVAssetExportSession *exportSession = [[SDAVAssetExportSession alloc] initWithAsset:asset];
    
    exportSession.videoSettings =
    @{
      AVVideoCodecKey: AVVideoCodecH264,
      AVVideoWidthKey: @1280,
      AVVideoHeightKey: @720,
      AVVideoCompressionPropertiesKey: @
          {
          AVVideoAverageBitRateKey: @1100000,
          AVVideoProfileLevelKey: AVVideoProfileLevelH264High40,
          },
      };
    
    exportSession.audioSettings = @
    {
    AVFormatIDKey: @(kAudioFormatMPEG4AAC),
    AVNumberOfChannelsKey: @2,
    AVSampleRateKey: @44100,
    AVEncoderBitRateKey: @128000,
    };
    
    
    AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoATrack];
    CGAffineTransform orientationTransform = videoATrack.preferredTransform;
    CGAffineTransform transform = CGAffineTransformConcat(CGAffineTransformConcat(CGAffineTransformMakeScale(1, 1),  CGAffineTransformMakeTranslation(0, 0)), orientationTransform);
    
    [layerInstruction setTransform:transform atTime:kCMTimeZero];
    
    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.layerInstructions = @[layerInstruction];
    instruction.timeRange = videoATrack.timeRange;
    
    AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
    videoComposition.renderSize = CGSizeMake(1280, 720);
    videoComposition.renderScale = 1.0;
    videoComposition.frameDuration = CMTimeMake(1, videoFPS);
    videoComposition.instructions = @[instruction];

    exportSession.videoComposition = videoComposition;
    
    NSString *uniqueFilename = [NSUUID new].UUIDString;
    
    //exportSession.videoComposition = videoComposition;
    
    exportSession.outputURL = [NSURL fileURLWithPath:[[NSTemporaryDirectory() stringByAppendingPathComponent:uniqueFilename] stringByAppendingPathExtension:@"MP4"]];
    
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.shouldOptimizeForNetworkUse = YES;
    
    NSLog(@"Exporting! Path = %@", exportSession.outputURL);
    
    // If file has already exported, upload it immediately
    if ([[NSFileManager defaultManager] fileExistsAtPath:exportSession.outputURL.path])
    {
        abort(); // should not happen
    }
    
    NSDate *startDate = [NSDate date];
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            
            NSLog(@"done");
            
            if (exportSession.status == AVAssetExportSessionStatusCompleted)  {
                
                NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:exportSession.outputURL.path error:nil];
                
                
                NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
                NSString *compressedSize = [NSByteCountFormatter stringFromByteCount:fileSizeNumber.longLongValue countStyle:NSByteCountFormatterCountStyleFile];
                
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Video exported" message:[NSString stringWithFormat:@"original size: %@\ncompressed size: %@\nexport duration: %fs", originalSize, compressedSize, -startDate.timeIntervalSinceNow] preferredStyle:UIAlertControllerStyleAlert];
                
                [self presentViewController:alert animated:YES completion:nil];
                
                ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                [library writeVideoAtPathToSavedPhotosAlbum:exportSession.outputURL completionBlock:^(NSURL *assetURL, NSError *error){
                    if(error) {
                        NSLog(@"CameraViewController: Error on saving movie : %@ {imagePickerController}", error);
                    }
                    else {
                        NSLog(@"URL: %@", assetURL);
                    }
                }];
                
            } else {
                NSLog(@"error: %@", exportSession.error);
            }
        });
    }];

}

@end
