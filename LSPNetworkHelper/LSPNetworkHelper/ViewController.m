//
//  ViewController.m
//  LSPNetworkHelper
//
//  Created by lishaopeng on 16/8/23.
//  Copyright © 2016年 lishaopeng. All rights reserved.
//

#import "ViewController.h"
#import "LSPNetworkHelper.h"


static NSString *const dataUrl = @"http://www.qinto.com/wap/index.php?ctl=article_cate&act=api_app_getarticle_cate&num=1&p=1";
static NSString *const downloadUrl = @"http://wvideo.spriteapp.cn/video/2016/0328/56f8ec01d9bfe_wpd.mp4";

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *networkTextView;
@property (weak, nonatomic) IBOutlet UITextView *cacheTextView;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UISwitch *cacheSwich;
@property (weak, nonatomic) IBOutlet UIButton *downloadButton;

/** 是否开启缓存*/
@property (nonatomic, assign, getter=isCache) BOOL cache;

/** 是否开始下载*/
@property (nonatomic, assign, getter=isDownload) BOOL download;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"网络缓存大小 = %fMB",[LSPNetworkCache getAllHttpCacheSize]/1024/1024.f);
    //检测网络状态
    [LSPNetworkHelper networkStatusWithBlock:^(LSPNetworkStatusType status) {
        switch (status) {
            case LSPNetworkStatusUnknown:{
                self.networkTextView.text = @"亲，没有网络";
                //从缓存加载数据
                
                break;
            }
            case LSPNetworkstatusReachableWWAN:{
                [self getData:[[NSUserDefaults standardUserDefaults] boolForKey:@"isOn"] url:dataUrl];
            }
            case LSPNetworkStatusReachableWiFi:{
                [self getData:[[NSUserDefaults standardUserDefaults] boolForKey:@"isOn"] url:dataUrl];
            }
            default:
                break;
        }
    }];
    // 一次性获取当前网络状态
    [self currentNetworkStatus];
}
#pragma mark - 一次性网络状态判断
- (void)currentNetworkStatus
{
    if (IsNetwork) {
        NSLog(@"有网络");
        if (IsWWANNetwork) {
            NSLog(@"手机网络");
        }else if (IsWiFiNetwork){
            NSLog(@"WiFi网络");
        }
    }
}
-(void)getData:(BOOL)isOn url:(NSString *)url{
    //自动缓存
    if(isOn)
    {
        
        self.cacheSwich.on = YES;
        [LSPNetworkHelper GETWithURL:url parameters:nil responseCache:^(id responseCache) {
            
            self.cacheTextView.text = [self jsonToString:responseCache];
            
        } success:^(id responseObject) {
            
            self.networkTextView.text = [self jsonToString:responseObject];
            
        } failure:^(NSError *error) {
            NSLog(@"error = %@",error);
        }];
        
    }
    //无缓存
    else
    {
        
        self.cacheSwich.on = NO;
        self.cacheTextView.text = @"";
        [LSPNetworkHelper GETWithURL:url parameters:nil success:^(id responseObject) {
            self.networkTextView.text = [self jsonToString:responseObject];
        } failure:^(NSError *error) {
            
        }];
        
    }
}
- (IBAction)downLoadButtonClick:(UIButton *)sender {
    static NSURLSessionTask *task = nil;
    //开始下载
    if(!self.isDownload)
    {
        self.download = YES;
        [self.downloadButton setTitle:@"取消下载" forState:UIControlStateNormal];
        
        task = [LSPNetworkHelper downloadWithURLStr:downloadUrl fileDir:@"Download" progress:^(NSProgress *progress) {
            
            CGFloat stauts = 100.f * progress.completedUnitCount/progress.totalUnitCount;
            self.progressView.progress = stauts/100.f;
            
            NSLog(@"下载进度 :%.2f%%,,%@",stauts,[NSThread currentThread]);
        } success:^(NSString *filePath) {
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"下载完成!"
                                                                message:[NSString stringWithFormat:@"文件路径:%@",filePath]
                                                               delegate:nil
                                                      cancelButtonTitle:@"确定"
                                                      otherButtonTitles:nil];
            [alertView show];
            [self.downloadButton setTitle:@"重新下载" forState:UIControlStateNormal];
            NSLog(@"filePath = %@",filePath);
            
        } failure:^(NSError *error) {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"下载失败"
                                                                message:[NSString stringWithFormat:@"%@",error]
                                                               delegate:nil
                                                      cancelButtonTitle:@"确定"
                                                      otherButtonTitles:nil];
            [alertView show];
            NSLog(@"error = %@",error);
        }];
        
    }
    //暂停下载
    else
    {
        self.download = NO;
        [task suspend];
        self.progressView.progress = 0;
        [self.downloadButton setTitle:@"开始下载" forState:UIControlStateNormal];
    }
}
- (IBAction)cacheSwichChange:(UISwitch *)sender {
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    [userDefault setBool:sender.isOn forKey:@"isOn"];
    [userDefault synchronize];
    
    [self getData:sender.isOn url:dataUrl];
}


/**
 *  json转字符串
 */
- (NSString *)jsonToString:(NSDictionary *)dic
{
    if(!dic){
        return nil;
    }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:nil];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}


@end
