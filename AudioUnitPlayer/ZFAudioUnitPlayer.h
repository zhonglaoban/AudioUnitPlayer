//
//  ZFAudioUnitPlayer.h
//  AudioUnitPlayer
//
//  Created by 钟凡 on 2020/1/17.
//  Copyright © 2020 钟凡. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ZFAudioUnitPlayerDataSourse <NSObject>

- (void)readDataToBuffer:(AudioBufferList *)ioData length:(UInt32)inNumberFrames;

@end


@interface ZFAudioUnitPlayer : NSObject
@property (nonatomic, weak) id<ZFAudioUnitPlayerDataSourse> dataSource;

- (instancetype)initWithAsbd:(AudioStreamBasicDescription)asbd;

- (void)startPlay;
- (void)stopPlay;

@end

NS_ASSUME_NONNULL_END
