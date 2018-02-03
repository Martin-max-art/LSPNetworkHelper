//
//  LSPNetworkHelper.m
//  LSPNetworkHelper
//
//  Created by lishaopeng on 16/8/23.
//  Copyright © 2016年 lishaopeng. All rights reserved.
//

#import "LSPNetworkHelper.h"
#import <AFNetworking.h>
#import <AFNetworkActivityIndicatorManager.h>

#ifdef DEBUG
#define LSLog(...) printf("[%s] %s [第%d行]: %s\n",__TIME__,__PRETTY_FUNCTION__,__LINE__,[[NSString stringWithFormat:__VA_ARGS__] UTF8String])
#else
#define LSLog(...)
#endif


@implementation LSPNetworkHelper

static NSMutableArray *_allSessionTask;
static AFHTTPSessionManager *_sessionManager;

/*实时获取网络状态，此方法可多次调用*/
+ (void)networkStatusWithBlock:(LSPNetworkStatus)networkStatus{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            switch (status) {
                case AFNetworkReachabilityStatusUnknown:
                    networkStatus ? networkStatus(LSPNetworkStatusUnknown) : nil;
                    break;
                case AFNetworkReachabilityStatusNotReachable:
                    networkStatus ? networkStatus(LSPNetworkStatusNotReachable) : nil;
                    break;
                case AFNetworkReachabilityStatusReachableViaWWAN:
                    networkStatus ? networkStatus(LSPNetworkstatusReachableWWAN) : nil;
                    break;
                case AFNetworkReachabilityStatusReachableViaWiFi:
                    networkStatus ? networkStatus(LSPNetworkStatusReachableWiFi) : nil;
                    break;
                default:
                    break;
            }
        }];
    });
}
+ (BOOL)isNetwork{
    return [AFNetworkReachabilityManager sharedManager].reachable;
}
+ (BOOL)isWiFiNetwork{
    return [AFNetworkReachabilityManager sharedManager].reachableViaWiFi;
}
+ (BOOL)isWWANNetwork{
    return [AFNetworkReachabilityManager sharedManager].reachableViaWWAN;
}
+ (void)cancelAllRequest{
    @synchronized (self) {
        [[self allSessionTask]enumerateObjectsUsingBlock:^(NSURLSessionTask  *_Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            [task cancel];
        }];
        [[self allSessionTask]removeAllObjects];
    }
}
+ (void)cancelRequestWithURLStr:(NSString *)URLStr{
    if (!URLStr) { return; }
    @synchronized (self) {
        [[self allSessionTask]enumerateObjectsUsingBlock:^(NSURLSessionTask  *_Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([task.currentRequest.URL.absoluteString hasPrefix:URLStr]) {
                [task cancel];
                [[self allSessionTask]removeObject:task];
                *stop = YES;
            }
        }];
    }
}
#pragma mark -- GET请求无缓存
+(NSURLSessionTask *)GETWithURL:(NSString *)URL parameters:(NSDictionary *)parameters success:(LSPHttpRequestSuccess)success failure:(LSPHttpRequestFailed)failure{
    
    return [self GETWithURL:URL parameters:parameters responseCache:nil success:success failure:failure];
}

#pragma mark -- GET请求带缓存
+ (__kindof NSURLSessionTask *)GETWithURL:(NSString *)URL
                               parameters:(NSDictionary *)parameters
                            responseCache:(LSPHttpRequestCache)responseCache
                                  success:(LSPHttpRequestSuccess)success
                                  failure:(LSPHttpRequestFailed)failure{
//    //读取缓存
    responseCache ? [LSPNetworkCache httpCacheForURL:URL parameters:parameters withBlock:responseCache] : nil;
    
    NSURLSessionTask *sessionTask = [_sessionManager GET:URL parameters:parameters progress:^(NSProgress * _Nonnull downloadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        //LSLog(@"GET_response = %@",[self jsonToString:responseObject]);
        [[self allSessionTask]removeObject:task];
        success ? success(responseObject) : nil;
        //对数据进行异步缓存
        responseCache ? [LSPNetworkCache setHttpCache:responseObject URL:URL parameters:parameters] : nil;
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [[self allSessionTask]removeObject:task];
        failure ? failure(error) : nil;
    }];
    //添加sessionTask到数组
    sessionTask ? [[self allSessionTask] addObject:sessionTask] : nil;
    return sessionTask;
}
#pragma mark -- POST请求无缓存
+(NSURLSessionTask *)POSTWithURL:(NSString *)URL parameters:(NSDictionary *)parameters success:(LSPHttpRequestSuccess)success failure:(LSPHttpRequestFailed)failure{
    return [self POSTWithURL:URL parameters:parameters responseCache:nil success:success failure:failure];
}

#pragma mark -- POST请求带缓存
+(NSURLSessionTask *)POSTWithURL:(NSString *)URL parameters:(NSDictionary *)parameters responseCache:(LSPHttpRequestCache)responseCache success:(LSPHttpRequestSuccess)success failure:(LSPHttpRequestFailed)failure{
    
    //读取缓存
    responseCache ? [LSPNetworkCache httpCacheForURL:URL parameters:parameters withBlock:responseCache] : nil;
    
    NSURLSessionTask *sessionTask = [_sessionManager POST:URL parameters:parameters progress:^(NSProgress * _Nonnull uploadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        LSLog(@"POST_response = %@",[self jsonToString:responseObject]);
        [[self allSessionTask]removeObject:task];
        success ? success(responseObject) : nil;
        //对数据进行异步缓存
        responseCache ? [LSPNetworkCache setHttpCache:responseCache URL:URL parameters:parameters] : nil;
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        [[self allSessionTask]removeObject:task];
        failure ? failure(error) : nil;
    }];
    
    //添加最新的sessionTask到数组
    sessionTask ? [[self allSessionTask]addObject:sessionTask] : nil;
    return sessionTask;
}
#pragma mark -- 上传图片文件
+ (NSURLSessionTask *)uploadURLStr:(NSString *)URLStr parameters:(NSDictionary *)parameters images:(NSArray<UIImage *> *)images name:(NSString *)name fileName:(NSString *)fileName mimeType:(NSString *)mimeType progress:(LSPHttpProgress)progress success:(LSPHttpRequestSuccess)success failure:(LSPHttpRequestFailed)failure{
    NSURLSessionTask *sessionTask = [_sessionManager POST:URLStr parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        //压缩-添加-上传图片
        [images enumerateObjectsUsingBlock:^(UIImage * _Nonnull image, NSUInteger idx, BOOL * _Nonnull stop) {
            
            NSData *imageData = UIImageJPEGRepresentation(image, 0.5);
            [formData appendPartWithFileData:imageData name:name fileName:[NSString stringWithFormat:@"%@%lu.%@",fileName,(unsigned long)idx,mimeType ? mimeType : @"jpeg"] mimeType:[NSString stringWithFormat:@"image/%@",mimeType ? mimeType : @"jpeg"]];
        }];
        
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        //上传进度
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(uploadProgress) : nil;
        });
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        [[self allSessionTask]removeObject:task];
        success ? success(responseObject) : nil;
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        [[self allSessionTask]removeObject:task];
        failure ? failure(error) : nil;
    }];
    //添加最新的sessionTask到数组
    sessionTask ? [[self allSessionTask]addObject:sessionTask] : nil;
    return sessionTask;
}
#pragma mark -- 下载文件
+(NSURLSessionTask *)downloadWithURLStr:(NSString *)URLStr fileDir:(NSString *)fileDir progress:(LSPHttpProgress)progress success:(LSPHttpRequestSuccess)success failure:(LSPHttpRequestFailed)failure{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:URLStr]];
   __block NSURLSessionDownloadTask *downloadTask = [_sessionManager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        
        LSLog(@"下载进度:%.2f%%",100.0*downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(downloadProgress) : nil;
        });
        
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        //拼接缓存目录
        NSString *downloadDir = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject]stringByAppendingPathComponent:fileDir ? fileDir : @"Download"];
        
        //打开文件管理器
        NSFileManager *fileManager = [NSFileManager defaultManager];
        //创建DownLoad目录
        [fileManager createDirectoryAtPath:downloadDir withIntermediateDirectories:YES attributes:nil error:nil];
        //拼接文件路径
        NSString *filePath = [downloadDir stringByAppendingPathComponent:response.suggestedFilename];
        
        return [NSURL fileURLWithPath:filePath];
        
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        [[self allSessionTask]removeObject:downloadTask];
        if (failure && error) {
            failure(error);
            return;
        }
        success ? success(filePath.absoluteString) : nil;
    }];
    //开始下载
    [downloadTask resume];
    
    //添加sessionTask到数组
    downloadTask ? [[self allSessionTask]addObject:downloadTask] : nil;
    return downloadTask;
}
/*json转字符串*/
+ (NSString *)jsonToString:(id)data
{
    if(!data){ return nil; }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:nil];
    return [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
}
/*所有的请求task数组*/
+ (NSMutableArray *)allSessionTask{
    if (!_allSessionTask) {
        _allSessionTask = [NSMutableArray array];
    }
    return _allSessionTask;
}
#pragma mark -- 初始化AFHTTPSessionManager相关属性
+ (void)initialize{
    _sessionManager = [AFHTTPSessionManager manager];
    //设置请求超时时间
    _sessionManager.requestSerializer.timeoutInterval = 30.f;
    //设置服务器返回结果的类型:JSON(AFJSONResponseSerializer,AFHTTPResponseSerializer)
    _sessionManager.responseSerializer = [AFJSONResponseSerializer serializer];
    _sessionManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/html", @"text/json", @"text/plain", @"text/javascript", @"text/xml", @"image/*", nil];
    //开始监测网络状态
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    //打开状态栏菊花
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    
}

/************************************重置AFHTTPSessionManager相关属性**************/
#pragma mark -- 重置AFHTTPSessionManager相关属性
+ (void)setRequestSerializer:(LSPRequestSerializer)requestSerializer{
    _sessionManager.requestSerializer = requestSerializer==LSPRequestSerializerHTTP ? [AFHTTPRequestSerializer serializer] : [AFJSONRequestSerializer serializer];
}
+ (void)setResponseSerializer:(LSPResponseSerializer)responseSerializer{
    _sessionManager.responseSerializer = responseSerializer==LSPResponseSerializerHTTP ? [AFHTTPResponseSerializer serializer] : [AFJSONResponseSerializer serializer];
}
+ (void)setRequestTimeoutInterval:(NSTimeInterval)time{
    _sessionManager.requestSerializer.timeoutInterval = time;
}
+ (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field{
    [_sessionManager.requestSerializer setValue:value forHTTPHeaderField:field];
}
+ (void)openNetworkActivityIndicator:(BOOL)open{
    [[AFNetworkActivityIndicatorManager sharedManager]setEnabled:open];
}
+ (void)setSecurityPolicyWithCerPath:(NSString *)cerPath validatesDomainName:(BOOL)validatesDomainName{
    
    NSData *cerData = [NSData dataWithContentsOfFile:cerPath];
    //使用证书验证模式
    AFSecurityPolicy *securitypolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
    //如果需要验证自建证书(无效证书)，需要设置为YES
    securitypolicy.allowInvalidCertificates = YES;
    //是否需要验证域名，默认为YES
    securitypolicy.validatesDomainName = validatesDomainName;
    securitypolicy.pinnedCertificates = [[NSSet alloc]initWithObjects:cerData, nil];
    [_sessionManager setSecurityPolicy:securitypolicy];
}

@end
#pragma mark -- NSDictionary,NSArray的分类
/*
 ************************************************************************************
 *新建NSDictionary与NSArray的分类, 控制台打印json数据中的中文
 ************************************************************************************
 */
//#ifdef DEBUG
@implementation NSArray (LSP)

- (NSString *)descriptionWithLocale:(id)locale{
    
    NSMutableString *strM = [NSMutableString stringWithString:@"(\n"];
    [self enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [strM appendFormat:@"\t%@,\n",obj];
    }];
    [strM appendString:@")\n"];
    return  strM;
}
@end

@implementation NSDictionary (LSP)

- (NSString *)descriptionWithLocale:(id)locale{
    
    NSMutableString *strM = [NSMutableString stringWithString:@"{\n"];
    [self enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [strM appendFormat:@"\t%@,\n",obj];
    }];
    [strM appendString:@"}\n"];
    return  strM;
}

@end
//#endif
