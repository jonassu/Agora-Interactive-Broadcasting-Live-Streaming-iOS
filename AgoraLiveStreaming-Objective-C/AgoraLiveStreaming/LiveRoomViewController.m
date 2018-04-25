//
//  LiveRoomViewController.m
//  AgoraLiveStreaming
//
//  Created by suleyu on 2018/4/20.
//  Copyright © 2018 Agora. All rights reserved.
//

#import "LiveRoomViewController.h"
#import "KeyCenter.h"

@interface LiveRoomViewController () <AgoraRtcEngineDelegate, UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UILabel *roomNameLabel;
@property (weak, nonatomic) IBOutlet UIView *localVideoView;
@property (weak, nonatomic) IBOutlet UIView *remoteVideoView;
@property (weak, nonatomic) IBOutlet UITextView *logTextView;
@property (weak, nonatomic) IBOutlet UIButton *publishStreamButton;
@property (weak, nonatomic) IBOutlet UIButton *audioMuteButton;

@property (strong, nonatomic) AgoraRtcEngineKit *rtcEngine;
@property (copy, nonatomic) NSString *publishUrl;
@property (assign, nonatomic) BOOL isMuted;

@property (assign, nonatomic) NSUInteger localUid;
@property (strong, nonatomic) NSMutableArray *remoteUids;

@end

@implementation LiveRoomViewController

- (void)setIsMuted:(BOOL)isMuted {
    _isMuted = isMuted;
    [self.rtcEngine muteLocalAudioStream:isMuted];
    [self.audioMuteButton setImage:[UIImage imageNamed:(isMuted ? @"btn_mute_cancel" : @"btn_mute")] forState:UIControlStateNormal];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.remoteUids = [[NSMutableArray alloc] init];
    
    self.roomNameLabel.text = self.roomName;
    
    [self loadAgoraKit];
    [self joinChannel];
}

- (IBAction)doPublishTapped:(UIButton *)sender {
    if (self.publishUrl == nil) {
        [self showPublishURLAlert];
    }
    else {
        [self stopPublishStream];
    }
}

- (void)showPublishURLAlert {
    NSString *title = @"Please input publish stream URL";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    __weak typeof(alert) weakAlert = alert;
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        __strong typeof(weakAlert) strongAlert = weakAlert;
        UITextField *textField = strongAlert.textFields.firstObject;
        NSString *url = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [self startPublishStream:url];
    }];
    okAction.enabled = NO;
    [alert addAction:okAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:cancelAction];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeURL;
        textField.returnKeyType = UIReturnKeyDone;
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UITextFieldTextDidChangeNotification object:textField queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            NSString *url = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            okAction.enabled = url.length > 0;
        }];
    }];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)doSwitchCameraPressed:(UIButton *)sender {
    [self.rtcEngine switchCamera];
}

- (IBAction)doMutePressed:(UIButton *)sender {
    self.isMuted = !self.isMuted;
}

- (IBAction)doLeavePressed:(UIButton *)sender {
    [self leaveChannel];
}

- (void)leaveChannel {
    [self setIdleTimerActive:YES];
    
    [self.rtcEngine setupLocalVideo:nil];
    [self.rtcEngine leaveChannel:nil];
    [self.rtcEngine stopPreview];
    
    if ([self.delegate respondsToSelector:@selector(liveVCNeedClose:)]) {
        [self.delegate liveVCNeedClose:self];
    }
}

- (void)setIdleTimerActive:(BOOL)active {
    [UIApplication sharedApplication].idleTimerDisabled = !active;
}

- (void)appendToLogView:(NSString*)text
{
    static NSDateFormatter *dateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd ah-mm-ss.SSS"];
    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *string = [NSString stringWithFormat:@"%@ %@\n", [dateFormatter stringFromDate:[NSDate date]], text];
        NSAttributedString* attr = [[NSAttributedString alloc] initWithString:string];
        
        [[self.logTextView textStorage] appendAttributedString:attr];
        [self.logTextView scrollRangeToVisible:NSMakeRange(self.logTextView.text.length, 0)];
    });
}

//MARK: - Agora SDK

- (void)loadAgoraKit {
    self.rtcEngine = [AgoraRtcEngineKit sharedEngineWithAppId:[KeyCenter AppId] delegate:self];
    [self.rtcEngine setChannelProfile:AgoraChannelProfileLiveBroadcasting];
    [self.rtcEngine enableVideo];
    [self.rtcEngine setVideoProfile:AgoraVideoProfileDEFAULT swapWidthAndHeight:YES];
    [self.rtcEngine setClientRole:AgoraClientRoleBroadcaster];
    
    AgoraRtcVideoCanvas *canvas = [[AgoraRtcVideoCanvas alloc] init];
    canvas.view = self.localVideoView;
    canvas.renderMode = AgoraVideoRenderModeHidden;
    [self.rtcEngine setupLocalVideo:canvas];
    
    [self.rtcEngine startPreview];
}

- (void)joinChannel {
    NSLog(@"start join channel");
    int code = [self.rtcEngine joinChannelByToken:nil channelId:self.roomName info:nil uid:0 joinSuccess:nil];
    if (code == 0) {
        [self setIdleTimerActive:NO];
    } else {
        NSString *log = [NSString stringWithFormat:@"Join channel failed: %d", code];
        [self appendToLogView:log];
    }
}

- (void)startPublishStream:(NSString *)url {
    if (url.length == 0) {
        return;
    }
    
    [self setLiveTranscoding];
    
    self.publishUrl = url;
    [self.rtcEngine addPublishStreamUrl:self.publishUrl transcodingEnabled:YES];
    
    [self.publishStreamButton setImage:[UIImage imageNamed:@"btn_rtmp_blue"] forState:UIControlStateNormal];
}

- (void)stopPublishStream {
    [self.rtcEngine removePublishStreamUrl:self.publishUrl];
    self.publishUrl = nil;
    
    [self.publishStreamButton setImage:[UIImage imageNamed:@"btn_rtmp"] forState:UIControlStateNormal];
}

- (void)setLiveTranscoding {
    AgoraLiveTranscoding *transcoding = [AgoraLiveTranscoding defaultTranscoding];
    transcoding.size = CGSizeMake(720, 640);
    transcoding.videoBitrate = 1000;
    transcoding.videoFramerate = 15;
    transcoding.lowLatency = YES;
    transcoding.backgroundColor = [UIColor blackColor];
    
    AgoraLiveTranscodingUser *localLayout = [[AgoraLiveTranscodingUser alloc] init];
    localLayout.uid = self.localUid;
    localLayout.rect = CGRectMake(0, 0, 360, 640);
    localLayout.zOrder = 1;
    localLayout.alpha = 1;
    
    if (self.remoteUids.count == 0) {
        transcoding.transcodingUsers = @[localLayout];
    }
    else {
        AgoraLiveTranscodingUser *remoteLayout = [[AgoraLiveTranscodingUser alloc] init];
        remoteLayout.uid = [self.remoteUids.firstObject unsignedIntegerValue];
        remoteLayout.rect = CGRectMake(360, 0, 360, 640);
        remoteLayout.zOrder = 1;
        remoteLayout.alpha = 1;
        
        transcoding.transcodingUsers = @[localLayout, remoteLayout];
    }
    
    [self.rtcEngine setLiveTranscoding:transcoding];
}

//MARK: - AgoraRtcEngineDelegate

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinChannel:(NSString*)channel withUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    NSString *log = [NSString stringWithFormat:@"Join channel success, uid: %lu", (unsigned long)uid];
    [self appendToLogView:log];
    
    self.localUid = uid;
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine firstLocalVideoFrameWithSize:(CGSize)size elapsed:(NSInteger)elapsed {
    NSLog(@"firstLocalVideoFrameWithSize, %f x %f", size.width, size.height);
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didRejoinChannel:(NSString *)channel withUid:(NSUInteger)uid elapsed:(NSInteger) elapsed {
    [self appendToLogView:@"didRejoinChannel"];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinedOfUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    NSString *log = [NSString stringWithFormat:@"remote user joined: %lu", (unsigned long)uid];
    [self appendToLogView:log];
    
    [self.remoteUids addObject:@(uid)];
    
    if (self.remoteUids.count == 1) {
        if (self.publishUrl) {
            [self setLiveTranscoding];
        }
        
        AgoraRtcVideoCanvas *canvas = [[AgoraRtcVideoCanvas alloc] init];
        canvas.uid = uid;
        canvas.view = self.remoteVideoView;
        canvas.renderMode = AgoraVideoRenderModeHidden;
        [self.rtcEngine setupRemoteVideo:canvas];
    }
}

- (void)rtcEngine:(AgoraRtcEngineKit * _Nonnull)engine firstRemoteVideoFrameOfUid:(NSUInteger)uid size:(CGSize)size elapsed:(NSInteger)elapsed {
    NSLog(@"firstRemoteVideoFrameOfUid, %lu, size: %f x %f", (unsigned long)uid, size.width, size.height);
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOfflineOfUid:(NSUInteger)uid reason:(AgoraUserOfflineReason)reason {
    NSString *log = [NSString stringWithFormat:@"remote user offline: %lu", (unsigned long)uid];
    [self appendToLogView:log];
    
    BOOL isCurrect = [self.remoteUids indexOfObject:@(uid)] == 0;
    [self.remoteUids removeObject:@(uid)];
    
    if (isCurrect) {
        if (self.publishUrl) {
            [self setLiveTranscoding];
        }
        
        AgoraRtcVideoCanvas *canvas = [[AgoraRtcVideoCanvas alloc] init];
        canvas.uid = uid;
        [self.rtcEngine setupRemoteVideo:canvas];
        
        if (self.remoteUids.count > 0) {
            AgoraRtcVideoCanvas *canvas = [[AgoraRtcVideoCanvas alloc] init];
            canvas.uid = [self.remoteUids.firstObject unsignedIntegerValue];
            canvas.view = self.remoteVideoView;
            canvas.renderMode = AgoraVideoRenderModeHidden;
            [self.rtcEngine setupRemoteVideo:canvas];
        }
        else {
            NSArray *subviews = self.remoteVideoView.subviews;
            for (UIView *subview in subviews) {
                [subview removeFromSuperview];
            }
        }
    }
}

- (void)rtcEngine:(AgoraRtcEngineKit * _Nonnull)engine streamPublishedWithUrl:(NSString * _Nonnull)url errorCode:(AgoraErrorCode)errorCode {
    NSString *log = [NSString stringWithFormat:@"streamPublishedWithUrl: %@, error: %d", url, (int)errorCode];
    [self appendToLogView:log];
    
    if (errorCode != 0 && [url isEqualToString:self.publishUrl]) {
        self.publishUrl = nil;
        [self.publishStreamButton setImage:[UIImage imageNamed:@"btn_rtmp"] forState:UIControlStateNormal];
    }
}

- (void)rtcEngine:(AgoraRtcEngineKit * _Nonnull)engine streamUnpublishedWithUrl:(NSString * _Nonnull)url {
    NSString *log = [NSString stringWithFormat:@"streamUnpublishedWithUrl: %@", url];
    [self appendToLogView:log];
}

- (void)rtcEngineTranscodingUpdated:(AgoraRtcEngineKit * _Nonnull)engine {
    [self appendToLogView:@"rtcEngineTranscodingUpdated"];
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOccurWarning:(AgoraWarningCode)warningCode {
    NSLog(@"didOccurWarning: %d", (int)warningCode);
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOccurError:(AgoraErrorCode)errorCode {
    NSString *log = [NSString stringWithFormat:@"didOccurError: %d", (int)errorCode];
    [self appendToLogView:log];
}

- (void)rtcEngineConnectionDidInterrupted:(AgoraRtcEngineKit * _Nonnull)engine {
    [self appendToLogView:@"rtcEngineConnectionDidInterrupted"];
}

- (void)rtcEngineConnectionDidLost:(AgoraRtcEngineKit *)engine {
    [self appendToLogView:@"rtcEngineConnectionDidLost"];
}

@end
