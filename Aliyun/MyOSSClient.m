//
//  OSSClient.m
//  Aliyun
//
//  Created by 魏唯隆 on 2017/3/24.
//  Copyright © 2017年 魏唯隆. All rights reserved.
//

#import "MyOSSClient.h"

NSString *const endPoint = @"https://oss-cn-shenzhen.aliyuncs.com";
NSString *const AccessKey = @"LTAIQtPpBNSOCDSI";
NSString *const SecretKey = @"LBHib2qI9827uFyzBhprWsdprCY9WO";

@implementation MyOSSClient
+ (instancetype)sharedInstance {
    static MyOSSClient *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self _initClient];
    });
    return instance;
}

+ (MyOSSClient *)_initClient {
    // 打开调试log
    [OSSLog enableLog];
    
    // oss-cn-shenzhen	oss-cn-shenzhen.aliyuncs.com	oss-cn-shenzhen-internal.aliyuncs.com
    
    id<OSSCredentialProvider> credential = [[OSSPlainTextAKSKPairCredentialProvider alloc] initWithPlainTextAccessKey:AccessKey secretKey:SecretKey];
    
    OSSClientConfiguration * conf = [OSSClientConfiguration new];
    conf.maxRetryCount = 3; // 网络请求遇到异常失败后的重试次数
    conf.timeoutIntervalForRequest = 30; // 网络请求的超时时间
    conf.timeoutIntervalForResource = 24 * 60 * 60; // 允许资源传输的最长时间
    
    MyOSSClient *client = [[MyOSSClient alloc] initWithEndpoint:endPoint credentialProvider:credential clientConfiguration:conf];
    return client;
}


@end
