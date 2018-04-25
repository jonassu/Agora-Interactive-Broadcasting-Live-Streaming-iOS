//
//  LiveRoomViewController.h
//  AgoraLiveStreaming
//
//  Created by suleyu on 2018/4/20.
//  Copyright © 2018 Agora. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AgoraRtcEngineKit/AgoraRtcEngineKit.h>

@class LiveRoomViewController;
@protocol LiveRoomVCDelegate <NSObject>
- (void)liveVCNeedClose:(LiveRoomViewController *)liveVC;
@end

@interface LiveRoomViewController : UIViewController
@property (copy, nonatomic) NSString *roomName;
@property (weak, nonatomic) id<LiveRoomVCDelegate> delegate;
@end
