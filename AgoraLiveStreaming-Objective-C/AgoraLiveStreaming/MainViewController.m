//
//  MainViewController.m
//  AgoraLiveStreaming
//
//  Created by suleyu on 2018/4/20.
//  Copyright © 2018 Agora. All rights reserved.
//

#import "MainViewController.h"
#import "LiveRoomViewController.h"

@interface MainViewController () <LiveRoomVCDelegate, UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UITextField *roomNameTextField;
@property (weak, nonatomic) IBOutlet UIView *popoverSourceView;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSString *segueId = segue.identifier;
    
    if ([segueId isEqualToString:@"mainToLive"]) {
        LiveRoomViewController *liveVC = segue.destinationViewController;
        liveVC.roomName = self.roomNameTextField.text;
        liveVC.delegate = self;
    }
}

- (void)joinChannel {
    [self performSegueWithIdentifier:@"mainToLive" sender:nil];
}

- (void)liveVCNeedClose:(LiveRoomViewController *)liveVC {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)doJoinPressed:(UIButton *)sender {
    if (self.roomNameTextField.text.length) {
        [self joinChannel];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField.text.length) {
        [self joinChannel];
    }
    
    return YES;
}
@end
