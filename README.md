## Audio Unit 实现音频播放功能
![播放音频流程图](https://upload-images.jianshu.io/upload_images/3277096-be98158ce42211bb.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

使用Audio Unit播放音频的时候，我们使用一个`I/O Unit`就可以完成了，整体步骤和录制时差不多，具体如下：
1. 设置好AudioComponentDescription，确定我们使用的Audio Unit类型
2. 获取Audio Unit实例，我们有两种获取方式，通过AUGraph获取，通过AudioComponent获取。
3. 设置Audio Unit的属性，告诉系统我们需要使用Audio Unit的哪些功能以及需要采集什么样的数据。
4. 开始播放和停止播放。
5. 从回调函数中将音频数据传给播放器。

### 初始化
```objc
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
```

### 设置AudioComponentDescription
```objc
- (void)setupAcd {
    _ioUnitDesc.componentType = kAudioUnitType_Output;
    //vpio模式
    _ioUnitDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    _ioUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    _ioUnitDesc.componentFlags = 0;
    _ioUnitDesc.componentFlagsMask = 0;
}
```

### 获取Audio Unit实例
通过AUGraph获取实例
```objc
- (void)getAudioUnits {
    OSStatus status = NewAUGraph(&_graph);
    printf("create graph %d \n", (int)status);

    AUNode ioNode;
    status = AUGraphAddNode(_graph, &_ioUnitDesc, &ioNode);
    printf("add ioNote %d \n", (int)status);

    //instantiate the audio units
    status = AUGraphOpen(_graph);
    printf("open graph %d \n", (int)status);

    //obtain references to the audio unit instances
    status = AUGraphNodeInfo(_graph, ioNode, NULL, &_ioUnit);
    printf("get ioUnit %d \n", (int)status);
}
```
通过AudioComponent获取实例
```objc
- (void)createInputUnit {
    AudioComponent comp = AudioComponentFindNext(NULL, &_ioUnitDesc);
    if (comp == NULL) {
    printf("can't get AudioComponent");
    }
    OSStatus status = AudioComponentInstanceNew(comp, &(_ioUnit));
    printf("creat audio unit %d \n", (int)status);
}
```
### 设置Audio Unit属性
```objc
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
```
### 开始播放
注释的部分是不使用AUGraph的方式。
```objc
- (void)startRecord {
    dispatch_async(_queue, ^{
        OSStatus status;
        //  status = AudioUnitInitialize(self.ioUnit);
        //  printf("AudioUnitInitialize %d \n", (int)status);
        //  status = AudioOutputUnitStart(self.ioUnit);
        //  printf("AudioOutputUnitStart %d \n", (int)status);

        status = AUGraphInitialize(self.graph);
        printf("AUGraphInitialize %d \n", (int)status);
        status = AUGraphStart(self.graph);
        printf("AUGraphStart %d \n", (int)status);
    });
}
```

### 停止播放
```objc
- (void)stopRecord {
    dispatch_async(_queue, ^{
        OSStatus status;
        status = AUGraphStop(self.graph);
        printf("AUGraphStop %d \n", (int)status);
    });
}
```

### 回调中AURenderCallback填充数据
```objc
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
```
dataSource，从其他地方获取数据。这里是从文件中读取的数据，使用的是`ExtAudioFile`相关的API。

ExtAudioFile的使用-[简书地址](https://www.jianshu.com/p/03491bf9bd0b)
完整代码请到我的Github中下载-[项目地址](https://github.com/zhonglaoban/AudioUnitRecorder.git)
