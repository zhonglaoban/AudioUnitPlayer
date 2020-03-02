//
//  ZFAudioUnitPlayer.m
//  AudioUnitPlayer
//
//  Created by 钟凡 on 2020/1/17.
//  Copyright © 2020 钟凡. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "ZFAudioUnitPlayer.h"

static void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
    char errorString[20];
    // See if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else {
        // No, format it as an integer
        sprintf(errorString, "%d", (int)error);
        fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    }
}

static const double kSampleTime = 0.01;

@interface ZFAudioUnitPlayer()

@property (nonatomic, assign) AUGraph graph;
@property (nonatomic, assign) AUNode ioNode;
@property (nonatomic, assign) AudioUnit ioUnit;
@property (nonatomic, assign) AudioStreamBasicDescription asbd;
@property (nonatomic, assign) AudioComponentDescription ioDesc;
@property (nonatomic) dispatch_queue_t queue;

@end


@implementation ZFAudioUnitPlayer

- (instancetype)initWithAsbd:(AudioStreamBasicDescription)asbd {
    self = [super init];
    if (self) {
        _asbd = asbd;
        _queue = dispatch_queue_create("zf.audioPlayer", DISPATCH_QUEUE_SERIAL);
        [self setupDescription];
        [self getAudioUnits];
        [self setupAudioUnits];
    }
    return self;
}
- (void)setupDescription {
    _ioDesc.componentType = kAudioUnitType_Output;
    _ioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    _ioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    _ioDesc.componentFlags = 0;
    _ioDesc.componentFlagsMask = 0;
}
- (void)getAudioUnits {
    OSStatus status = NewAUGraph(&_graph);
    CheckError(status, "create graph");
    status = AUGraphAddNode(_graph, &_ioDesc, &_ioNode);
    CheckError(status, "create ioNote");
    
    status = AUGraphOpen(_graph);
    CheckError(status, "open graph");
    
    status = AUGraphNodeInfo(_graph, _ioNode, NULL, &_ioUnit);
    CheckError(status, "get ioNode reference");
}
- (void)setupAudioUnits {
    OSStatus status;
    //设置io输入格式
    status = AudioUnitSetProperty(_ioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &_asbd,
                                  sizeof(_asbd));
    CheckError(status, "set ioUnit StreamFormat");
    
    NSTimeInterval bufferDuration = kSampleTime;
    NSError *error;
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:bufferDuration error:&error];
    
    //设置输入回调
    AURenderCallbackStruct rcbs;
    rcbs.inputProc = &InputRenderCallback;
    rcbs.inputProcRefCon = (__bridge void *_Nullable)(self);
    status =  AudioUnitSetProperty(_ioUnit,
                                   kAudioUnitProperty_SetRenderCallback,
                                   kAudioUnitScope_Input,
                                   0,
                                   &rcbs,
                                   sizeof(rcbs));
    CheckError(status, "set render callback");
}
- (void)startPlay {
    dispatch_async(_queue, ^{
        OSStatus status;
        status = AUGraphInitialize(self.graph);
        CheckError(status, "AUGraphInitialize");
        status = AUGraphStart(self.graph);
        CheckError(status, "AUGraphStart");
    });
}
- (void)stopPlay {
    dispatch_async(_queue, ^{
        OSStatus status;
        status = AUGraphStop(self.graph);
        CheckError(status, "AUGraphStop");
        status = AUGraphUninitialize(self.graph);
        CheckError(status, "AUGraphUninitialize");
    });
}
static OSStatus InputRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData) {
    ZFAudioUnitPlayer *player = (__bridge ZFAudioUnitPlayer *)inRefCon;

    [player.dataSource readDataToBuffer:ioData length:inNumberFrames];
    
    return noErr;
}

@end



