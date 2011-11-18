//
//  ViewController.h
//  VKAPI
//
//  Created by Alexander on 05.11.11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UITextFieldDelegate> {
    IBOutlet UITextField *textField;
    IBOutlet UIButton *authButton;
    
    IBOutlet UIButton *shareText;
    IBOutlet UIButton *shareTextAndLink;
    IBOutlet UIButton *shareImage;
    
    NSString *appID;
    BOOL isAuth;
    BOOL isCaptcha;
}
@property (nonatomic, retain) NSString *appID;
@property (nonatomic, retain) IBOutlet UITextField *textField;
@property (nonatomic, retain) IBOutlet UIButton *authButton;

- (void) authComplete;
- (NSDictionary *) sendRequest:(NSString *)reqURl withCaptcha:(BOOL)captcha;
- (NSDictionary *) sendPOSTRequest:(NSString *)reqURl withImageData:(NSData *)imageData;
- (NSString *) URLEncodedString:(NSString *)str;
- (void) sendText;
- (void) sendTextAndLink;
- (void) sendFailedWithError:(NSString *)error;
- (void) sendSuccessWithMessage:(NSString *)message;
@end
