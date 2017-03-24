//
//  OSSClient.h
//  Aliyun
//
//  Created by 魏唯隆 on 2017/3/24.
//  Copyright © 2017年 魏唯隆. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AliyunOSSiOS/OSSService.h>

@interface MyOSSClient : OSSClient
+ (instancetype)sharedInstance;
@end
