//
//  ViewController.m
//  VKAPI
//
//  Created by Alexander on 05.11.11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"
#import "vkLoginViewController.h"
#import "JSONKit.h"

@implementation ViewController
@synthesize appID, textField, authButton;

- (void)dealloc {
    [appID release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    isAuth = NO;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}


- (BOOL)textFieldShouldReturn:(UITextField *)_textField{
	self.appID = textField.text;
	[textField resignFirstResponder];
	return YES;
}

- (IBAction)doAuth:(id)sender {
    vkLoginViewController *vk = [[vkLoginViewController alloc] init];
    self.appID = textField.text;
    vk.appID = appID;
    vk.delegate = self;
    [self presentModalViewController:vk animated:YES];
    [vk release];
    NSLog(@"doAuth");
}

- (void) authComplete {
    [self sendSuccessWithMessage:@"Авторизация прошла успешно!"];
    isAuth = YES;
    NSLog(@"isAuth: %@", isAuth ? @"YES":@"NO");
}

- (IBAction)logout:(id)sender {
    // Запрос на logout
    NSString *logout = @"http://api.vk.com/oauth/logout";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:logout] 
                                                            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                        timeoutInterval:60.0]; 
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    if(responseData){
        NSDictionary *dict = [[JSONDecoder decoder] parseJSONData:responseData];
        NSLog(@"Logout: %@", dict);
        
        // Приложение больше не авторизовано, можно удалить данные
        isAuth = NO;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"VKAccessUserId"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"VKAccessToken"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"VKAccessTokenDate"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [self sendSuccessWithMessage:@"Выход произведен успешно!"]; 
    }
}

- (IBAction)sendTextAction:(id)sender {
    if(!isAuth) return;
    [self sendText];
}

- (IBAction)sendTextAndUrlAction:(id)sender {
    if(!isAuth) return;
    [self sendTextAndLink];
}


- (IBAction)sendImageAction:(id)sender {
    if(!isAuth) return;
    /*  
     
     Отправка изображения на стену пользователя происходит в несколько этапов:
        1. Запрос сервера ВКонтакте для загрузки нашего изображения (photos.getWallUploadServer)
        2. По полученной ссылке в ответе сервера отправляем изображение методом POST
        3. Получив в ответе hash, photo, server отправлем команду на сохранение фото на стене (photos.saveWallPhoto)
        4. Получив в ответе photo id делаем запрос на размещение на стене картинки с помощью wall.post, где в качестве attachment указываем photo id
     
    */
    
    UIImage *image = [UIImage imageNamed:@"test.jpg"];
    NSString *user_id = [[NSUserDefaults standardUserDefaults] objectForKey:@"VKAccessUserId"];
    NSString *accessToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"VKAccessToken"];
    
    // Этап 1 
    NSString *getWallUploadServer = [NSString stringWithFormat:@"https://api.vk.com/method/photos.getWallUploadServer?owner_id=%@&access_token=%@", user_id, accessToken];
    
    NSDictionary *uploadServer = [self sendRequest:getWallUploadServer withCaptcha:NO];
    
    // Получаем ссылку для загрузки изображения
    NSString *upload_url = [[uploadServer objectForKey:@"response"] objectForKey:@"upload_url"];
    
    // Этап 2
    // Преобразуем изображение в NSData
    NSData *imageData = UIImageJPEGRepresentation(image, 1.0f);
    
    NSDictionary *postDictionary = [self sendPOSTRequest:upload_url withImageData:imageData];
    
    // Из полученного ответа берем hash, photo, server 
    NSString *hash = [postDictionary objectForKey:@"hash"];
    NSString *photo = [postDictionary objectForKey:@"photo"];
    NSString *server = [postDictionary objectForKey:@"server"];
    
    // Этап 3
    // Создаем запрос на сохранение фото на сервере вконтакте, в ответ получим id фото
    NSString *saveWallPhoto = [NSString stringWithFormat:@"https://api.vk.com/method/photos.saveWallPhoto?owner_id=%@&access_token=%@&server=%@&photo=%@&hash=%@", user_id, accessToken,server,photo,hash];
    
    NSDictionary *saveWallPhotoDict = [self sendRequest:saveWallPhoto withCaptcha:NO];
    
    NSDictionary *photoDict = [[saveWallPhotoDict objectForKey:@"response"] lastObject];
    NSString *photoId = [photoDict objectForKey:@"id"];
    
    // Этап 4 
    // Постим изображение на стену пользователя
     NSString *postToWallLink = [NSString stringWithFormat:@"https://api.vk.com/method/wall.post?owner_id=%@&access_token=%@&message=%@&attachment=%@", user_id, accessToken, [self URLEncodedString:@"К изображению можно добавить текст и ссылку"], photoId];
    
    NSDictionary *postToWallDict = [self sendRequest:postToWallLink withCaptcha:NO];
    NSString *errorMsg = [[postToWallDict  objectForKey:@"error"] objectForKey:@"error_msg"];
    if(errorMsg) {
        [self sendFailedWithError:errorMsg];
    } else {
        [self sendSuccessWithMessage:@"Картинка размещена на стене!"];
    }
    // Ура! Фото должно быть на стене!
    
}

- (void) getCaptcha {
    NSString *captcha_img = [[NSUserDefaults standardUserDefaults] objectForKey:@"captcha_img"];
    UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Введите код:\n\n\n\n\n"
                                                          message:@"\n" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
    
    UIImageView *imageView = [[[UIImageView alloc] initWithFrame:CGRectMake(12.0, 45.0, 130.0, 50.0)] autorelease];
    imageView.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:captcha_img]]];
    [myAlertView addSubview:imageView];
    
    UITextField *myTextField = [[[UITextField alloc] initWithFrame:CGRectMake(12.0, 110.0, 260.0, 25.0)] autorelease];
    [myTextField setBackgroundColor:[UIColor whiteColor]];
    
    // Отключаем автокорректировку
    myTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    // Отключаем автокапитализацию
    myTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    myTextField.tag = 33;
    
    [myAlertView addSubview:myTextField];
    [myAlertView show];
    [myAlertView release];
}

- (void)alertView:(UIAlertView *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(isCaptcha && buttonIndex == 1){
        isCaptcha = NO;
        
        UITextField *myTextField = (UITextField *)[actionSheet viewWithTag:33];
        [[NSUserDefaults standardUserDefaults] setObject:myTextField.text forKey:@"captcha_user"];
        NSLog(@"Captcha entered: %@",myTextField.text);
        
        // Вспоминаем какой был последний запрос и делаем его еще раз
        NSString *request = [[NSUserDefaults standardUserDefaults] objectForKey:@"request"];
        
        NSDictionary *newRequestDict =[self sendRequest:request withCaptcha:YES];
        NSString *errorMsg = [[newRequestDict  objectForKey:@"error"] objectForKey:@"error_msg"];
        if(errorMsg) {
            [self sendFailedWithError:errorMsg];
        } else {
            [self sendSuccessWithMessage:@"Капча обработана успешно и запрос выполнен!"];
        }
    }
}

- (void) sendText {
    NSString *user_id = [[NSUserDefaults standardUserDefaults] objectForKey:@"VKAccessUserId"];
    NSString *accessToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"VKAccessToken"];
    
    NSString *text = @"Работать с ВКонтакте API легко!";
    
    // Создаем запрос на размещение текста на стене
    NSString *sendTextMessage = [NSString stringWithFormat:@"https://api.vk.com/method/wall.post?owner_id=%@&access_token=%@&message=%@", user_id, accessToken, [self URLEncodedString:text]];
    NSLog(@"sendTextMessage: %@", sendTextMessage);
    
    // Если запрос более сложный мы можем работать дальше с полученным ответом
    NSDictionary *result = [self sendRequest:sendTextMessage withCaptcha:NO];
    // Если есть описание ошибки в ответе
    NSString *errorMsg = [[result objectForKey:@"error"] objectForKey:@"error_msg"];
    if(errorMsg) {
        [self sendFailedWithError:errorMsg];
    } else {
        [self sendSuccessWithMessage:@"Текст размещен на стене!"];
    }
}

- (void) sendTextAndLink {
    NSString *user_id = [[NSUserDefaults standardUserDefaults] objectForKey:@"VKAccessUserId"];
    NSString *accessToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"VKAccessToken"];
    
    NSString *text = @"Работать с ВКонтакте API легко!";
    NSString *link = @"http://vkontakte.ru/developers.php?oid=-1&p=%D0%9E%D0%BF%D0%B8%D1%81%D0%B0%D0%BD%D0%B8%D0%B5_%D0%BC%D0%B5%D1%82%D0%BE%D0%B4%D0%BE%D0%B2_API";
    
    // Создаем запрос на размещение текста и ссылки на стене
    NSString *sendTextAndLinkMessage = [NSString stringWithFormat:@"https://api.vk.com/method/wall.post?owner_id=%@&access_token=%@&message=%@&attachment=%@", user_id, accessToken, [self URLEncodedString:text], link];
    
    NSLog(@"sendTextAndLinkMessage: %@", sendTextAndLinkMessage);
    
    // Если запрос более сложный мы можем работать дальше с полученным ответом
    NSDictionary *result = [self sendRequest:sendTextAndLinkMessage withCaptcha:NO];
    NSString *errorMsg = [[result objectForKey:@"error"] objectForKey:@"error_msg"];
    if(errorMsg) {
        [self sendFailedWithError:errorMsg];
    } else {
        [self sendSuccessWithMessage:@"Текст и ссылка размещены на стене!"];
    }
}

- (NSDictionary *) sendRequest:(NSString *)reqURl withCaptcha:(BOOL)captcha {
    // Если это запрос после ввода капчи, то добавляем в запрос параметры captcha_sid и captcha_key
    if(captcha == YES){
        NSString *captcha_sid = [[NSUserDefaults standardUserDefaults] objectForKey:@"captcha_sid"];
        NSString *captcha_user = [[NSUserDefaults standardUserDefaults] objectForKey:@"captcha_user"];
        // Добавляем к запросу данные для капчи. Не забываем что введенный пользователем текст нужно обработать.
        reqURl = [reqURl stringByAppendingFormat:@"&captcha_sid=%@&captcha_key=%@", captcha_sid, [self URLEncodedString: captcha_user]];
    }
    NSLog(@"Sending request: %@", reqURl);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:reqURl] 
                                                            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                        timeoutInterval:60.0]; 
    
    // Для простоты используется обычный запрос NSURLConnection, ответ сервера сохраняем в NSData
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    
    // Если ответ получен успешно, можем его посмотреть и заодно с помощью JSONKit получить NSDictionary
    if(responseData){
        NSDictionary *dict = [[JSONDecoder decoder] parseJSONData:responseData];
        
        // Если есть описание ошибки в ответе
        NSString *errorMsg = [[dict objectForKey:@"error"] objectForKey:@"error_msg"];
        
        NSLog(@"Server response: %@ \nError: %@", dict, errorMsg);
        
        // Если требуется ввод капчи
        if([errorMsg isEqualToString:@"Captcha needed"]){
            isCaptcha = YES;
            // Сохраняем параметры для капчи
            NSString *captcha_sid = [[dict objectForKey:@"error"] objectForKey:@"captcha_sid"];
            NSString *captcha_img = [[dict objectForKey:@"error"] objectForKey:@"captcha_img"];
            [[NSUserDefaults standardUserDefaults] setObject:captcha_img forKey:@"captcha_img"];
            [[NSUserDefaults standardUserDefaults] setObject:captcha_sid forKey:@"captcha_sid"];
            // Сохраняем url запроса чтобы сделать его повторно после ввода капчи
            [[NSUserDefaults standardUserDefaults] setObject:reqURl forKey:@"request"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            [self getCaptcha];
        }
        
        return dict;
    }
    return nil;
}

- (NSDictionary *) sendPOSTRequest:(NSString *)reqURl withImageData:(NSData *)imageData {
    NSLog(@"Sending request: %@", reqURl);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:reqURl] 
                                                                      cachePolicy:NSURLRequestReloadIgnoringLocalCacheData 
                                                                  timeoutInterval:60.0]; 
    // Устанавливаем метод POST
    [request setHTTPMethod:@"POST"]; 
    
    // Кодировка UTF-8
    [request addValue:@"8bit" forHTTPHeaderField:@"Content-Transfer-Encoding"];
    
    CFUUIDRef uuid = CFUUIDCreate(nil);
    NSString *uuidString = [(NSString*)CFUUIDCreateString(nil, uuid) autorelease];
    CFRelease(uuid);
    NSString *stringBoundary = [NSString stringWithFormat:@"0xKhTmLbOuNdArY-%@",uuidString];
    NSString *endItemBoundary = [NSString stringWithFormat:@"\r\n--%@\r\n",stringBoundary];
    
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data;  boundary=%@", stringBoundary];
    
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
   
    NSMutableData *body = [NSMutableData data];
    
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n",stringBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithString:@"Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[@"Content-Type: image/jpg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:imageData];        
    [body appendData:[[NSString stringWithFormat:@"%@",endItemBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // Добавляем body к NSMutableRequest
    [request setHTTPBody:body];
    
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
    NSDictionary *dict;
    if(responseData){
        dict = [[JSONDecoder decoder] parseJSONData:responseData];
        
        // Если есть описание ошибки в ответе
        NSString *errorMsg = [[dict objectForKey:@"error"] objectForKey:@"error_msg"];
        
        NSLog(@"Server response: %@ \nError: %@", dict, errorMsg);
        
        return dict;
    }
    return nil;
}

- (void) sendFailedWithError:(NSString *)error {
    if(isCaptcha) return;
    UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Ошибка!"
                                                          message:error delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [myAlertView show];
    [myAlertView release];
}

- (void) sendSuccessWithMessage:(NSString *)message {
    UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"Успешно!"
                                                          message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [myAlertView show];
    [myAlertView release];
}

// Функция преобразования текста в подходящий для передачи формат
- (NSString *)URLEncodedString:(NSString *)str
{
    NSString *result = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                           (CFStringRef)str,
                                                                           NULL,
																		   CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                           kCFStringEncodingUTF8);
    [result autorelease];
	return result;
}

@end
