//
//  vkLoginViewController.m
//  VKAPI
//
//  Created by Alexander on 05.11.11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "vkLoginViewController.h"
#import "ViewController.h"

@implementation vkLoginViewController
@synthesize vkWebView, appID, delegate;

- (void) dealloc {
    [delegate release];
    [appID release];
    vkWebView.delegate = nil;
    [vkWebView release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
}

#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if(!vkWebView){
        self.vkWebView = [[UIWebView alloc] initWithFrame:self.view.bounds];
        vkWebView.delegate = self;
        vkWebView.scalesPageToFit = YES;
        [self.view addSubview:vkWebView];
    }
    // Создаем запрос на авторизацию приложения, указываем appID (код приложения, полученный при регистрации вконтакте по ссылке: http://vkontakte.ru/editapp?act=create&site=1) и нужные нам права, в данном случае это доступ к стене (wall), к фото (photos), чтобы можно было размещать фотографии на стену пользователя.
    
    if(!appID) {
        [self dismissModalViewControllerAnimated:YES];
        return;
    }
    NSString *authLink = [NSString stringWithFormat:@"http://api.vk.com/oauth/authorize?client_id=%@&scope=wall,photos&redirect_uri=http://api.vk.com/blank.html&display=touch&response_type=token", appID];
    NSURL *url = [NSURL URLWithString:authLink];
    
    [vkWebView loadRequest:[NSURLRequest requestWithURL:url]];
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [vkWebView stopLoading];
    vkWebView.delegate = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Web View Delegate

- (BOOL)webView:(UIWebView *)aWbView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {

    NSURL *URL = [request URL];
    // Пользователь нажал Отмена в веб-форме
    if ([[URL absoluteString] isEqualToString:@"http://api.vk.com/blank.html#error=access_denied&error_reason=user_denied&error_description=User%20denied%20your%20request"]) {
        [super dismissModalViewControllerAnimated:YES];
        return NO;
    }
	NSLog(@"Request: %@", [URL absoluteString]); 
	return YES;
}

-(void)webViewDidStartLoad:(UIWebView *)webView {

}

-(void)webViewDidFinishLoad:(UIWebView *)webView {
    // Если есть токен сохраняем его
    if ([vkWebView.request.URL.absoluteString rangeOfString:@"access_token"].location != NSNotFound) {
        NSString *accessToken = [self stringBetweenString:@"access_token=" 
                                                andString:@"&" 
                                              innerString:[[[webView request] URL] absoluteString]];
        
        // Получаем id пользователя, пригодится нам позднее
        NSArray *userAr = [[[[webView request] URL] absoluteString] componentsSeparatedByString:@"&user_id="];
        NSString *user_id = [userAr lastObject];
        NSLog(@"User id: %@", user_id);
        if(user_id){
            [[NSUserDefaults standardUserDefaults] setObject:user_id forKey:@"VKAccessUserId"];
        }
        
        if(accessToken){
            [[NSUserDefaults standardUserDefaults] setObject:accessToken forKey:@"VKAccessToken"];
            // Сохраняем дату получения токена. Параметр expires_in=86400 в ответе ВКонтакта, говорит сколько будет действовать токен.
            // В данном случае, это для примера, мы можем проверять позднее истек ли токен или нет
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"VKAccessTokenDate"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        NSLog(@"vkWebView response: %@",[[[webView request] URL] absoluteString]);
        [(ViewController *)delegate authComplete];
        [self dismissModalViewControllerAnimated:YES];
    } else if ([vkWebView.request.URL.absoluteString rangeOfString:@"error"].location != NSNotFound) {
        NSLog(@"Error: %@", vkWebView.request.URL.absoluteString);
        [self dismissModalViewControllerAnimated:YES];
    }
    
}

-(void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    
    NSLog(@"vkWebView Error: %@", [error localizedDescription]);
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - Methods

- (NSString*)stringBetweenString:(NSString*)start 
                       andString:(NSString*)end 
                     innerString:(NSString*)str 
{
    NSScanner* scanner = [NSScanner scannerWithString:str];
    [scanner setCharactersToBeSkipped:nil];
    [scanner scanUpToString:start intoString:NULL];
    if ([scanner scanString:start intoString:NULL]) {
        NSString* result = nil;
        if ([scanner scanUpToString:end intoString:&result]) {
            return result;
        }
    }
    return nil;
}



@end
