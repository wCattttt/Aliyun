//
//  ViewController.m
//  Aliyun
//
//  Created by 魏唯隆 on 2017/3/24.
//  Copyright © 2017年 魏唯隆. All rights reserved.
//

#import "ViewController.h"

#import <AliyunOSSiOS/OSSService.h>
#import "MyOSSClient.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <AVFoundation/AVFoundation.h>

typedef enum {
    AllAsync = 0,
    PartSync,
    PartAsync
}UploadType;

@interface ViewController ()<UINavigationControllerDelegate, UIImagePickerControllerDelegate>
{
    MyOSSClient *_client;
    UploadType _uploadType;  // 上传类型
    __weak IBOutlet UITextView *_textView;
    
    NSString *_uploadId;
    NSMutableArray *_partInfos;
}
@end

NSString *const bucketName = @"sanzangshouyou";
NSString * const multipartUploadKey = @"multipartUploadObject";

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _client = [MyOSSClient sharedInstance];
    
}

// 整体异步
- (IBAction)allAsync:(id)sender {
    _uploadType = AllAsync;
    [self _initPickControl];
}


// 分片同步
- (IBAction)partSync:(id)sender {
    _uploadType = PartSync;
    [self _initPickControl];
}

// 分片异步
- (IBAction)partAsync:(id)sender {
    _uploadType = PartAsync;
    [self _initPickControl];
}

- (void)_initPickControl {
    UIImagePickerController *imgPickControl = [[UIImagePickerController alloc]init];
    imgPickControl.delegate = self;
    
    UIAlertController *alertControl = [UIAlertController alertControllerWithTitle:@"提示" message:@"选择图片来源" preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *photoAction = [UIAlertAction actionWithTitle:@"相册" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
        {
            imgPickControl.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
            imgPickControl.mediaTypes = @[(NSString *)kUTTypeMovie, (NSString *)kUTTypeMPEG];
            [self presentViewController:imgPickControl animated:YES completion:nil];
        }
    }];
    UIAlertAction *camearAction = [UIAlertAction actionWithTitle:@"拍照" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
        {
            imgPickControl.sourceType = UIImagePickerControllerSourceTypeCamera;
            [self presentViewController:imgPickControl animated:YES completion:nil];
        }
    }];
    [alertControl addAction:cancelAction];
    [alertControl addAction:photoAction];
    [alertControl addAction:camearAction];
    [self presentViewController:alertControl animated:YES completion:nil];
}

#pragma mark 图片选择协议UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
//    UIImage *image = info[UIImagePickerControllerOriginalImage];
    
    NSURL *fileUrl = info[UIImagePickerControllerMediaURL];
    
    NSData *data = [NSData dataWithContentsOfURL:fileUrl];
    
    
    _textView.text = @"";
    
    switch (_uploadType) {
        case AllAsync:
            [self uploadAllObjectAsync:data];
            break;
            
        case PartSync:
            [self _initPart];
            [self uploadPartObjectSync:data];
            break;
            
        case PartAsync:
        {
            [self _initPart];
            NSArray *datas = [self cutFileForFragments:data withPath:fileUrl];
            [self uploadPartObjectAsync:datas];
        }
            break;
            
        default:
            break;
    }
}

- (NSArray *)cutFileForFragments:(NSData *)data withPath:(NSURL *)pathUrl {
    
    NSUInteger offset = 500 * 1024;    // 单位 K  分片
    NSUInteger fileSize = data.length;
    // 块数
    NSUInteger chunks = (fileSize%offset==0)?(fileSize/offset):(fileSize/(offset) + 1);
    
    NSMutableArray *fragments = [[NSMutableArray alloc] initWithCapacity:0];
    for (NSUInteger i = 0; i < chunks; i ++) {
        
        NSData* data;
        
        NSFileHandle *readHandle = [NSFileHandle fileHandleForReadingFromURL:pathUrl error:nil];
        
        [readHandle seekToFileOffset:offset * i];
        
        data = [readHandle readDataOfLength:offset];
        
        [fragments addObject:data];
    }
    
    return fragments;
}

#pragma mark 异步上传
- (void)uploadAllObjectAsync:(NSData *)data {
    OSSPutObjectRequest * put = [OSSPutObjectRequest new];
    
    // required fields
    put.bucketName = bucketName;
    put.objectKey = multipartUploadKey;
//    put.uploadingFileURL = fileUrl;
    put.uploadingData = data;
    
    // optional fields
    put.uploadProgress = ^(int64_t bytesSent, int64_t totalByteSent, int64_t totalBytesExpectedToSend) {
        NSLog(@"%lld, %lld, %lld", bytesSent, totalByteSent, totalBytesExpectedToSend);
    };
    put.contentType = @"";
    put.contentMd5 = @"";
    put.contentEncoding = @"";
    put.contentDisposition = @"";
    
    OSSTask * putTask = [_client putObject:put];
    
    [putTask continueWithBlock:^id(OSSTask *task) {
        NSLog(@"objectKey: %@", put.objectKey);
        NSString *msg;
        if (!task.error) {
             msg = @"upload object success!";
            
        } else {
            msg = [NSString stringWithFormat:@"upload object failed, error: %@" , task.error];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            _textView.text = msg;
        });
        return nil;
    }];
}

#pragma mark 初始化分片上传  part 最小100k 最大10000K
- (void)_initPart {
    _uploadId = @"";
    _partInfos = @[].mutableCopy;
    
    NSString * uploadToBucket = bucketName;
    NSString * uploadObjectkey = multipartUploadKey;
    
    OSSInitMultipartUploadRequest * init = [OSSInitMultipartUploadRequest new];
    init.bucketName = uploadToBucket;
    init.objectKey = uploadObjectkey;
    
    // init.contentType = @"application/octet-stream";
    
    OSSTask * initTask = [_client multipartUploadInit:init];
    
    [initTask waitUntilFinished];
    
    if (!initTask.error) {
        OSSInitMultipartUploadResult * result = initTask.result;
        _uploadId = result.uploadId;
    } else {
        NSLog(@"multipart upload failed, error: %@", initTask.error);
        return;
    }
}

#pragma mark 同步分片上传
- (void)uploadPartObjectSync:(NSData *)data {
    for (int i = 1; i <= 5; i++) {
        OSSUploadPartRequest * uploadPart = [OSSUploadPartRequest new];
        uploadPart.bucketName = bucketName;
        uploadPart.objectkey = multipartUploadKey;
        uploadPart.uploadId = _uploadId;
        uploadPart.partNumber = i; // part number start from 1
        
        uploadPart.uploadPartData = data;
        
        OSSTask * uploadPartTask = [_client uploadPart:uploadPart];
        
        [uploadPartTask waitUntilFinished];
        
        if (!uploadPartTask.error) {
            OSSUploadPartResult * result = uploadPartTask.result;
            uint64_t fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:uploadPart.uploadPartFileURL.absoluteString error:nil] fileSize];
            [_partInfos addObject:[OSSPartInfo partInfoWithPartNum:i eTag:result.eTag size:fileSize]];
        } else {
            NSLog(@"upload part error: %@", uploadPartTask.error);
            return;
        }
    }
    
    [self ossComplete];

}

#pragma mark 异步分片上传
- (void)uploadPartObjectAsync:(NSArray *)datas {
    dispatch_group_t group = dispatch_group_create();
    // 分片上传
    for (int i = 1; i <= datas.count; i++) {
        dispatch_group_enter(group);
        
        OSSUploadPartRequest * uploadPart = [OSSUploadPartRequest new];
        uploadPart.bucketName = bucketName;
        uploadPart.objectkey = multipartUploadKey;
        uploadPart.uploadId = _uploadId;
        uploadPart.partNumber = i; // part number start from 1
        
        uploadPart.uploadPartData = datas[i-1];
        
        OSSTask * uploadPartTask = [_client uploadPart:uploadPart];
        
        [uploadPartTask continueWithBlock:^id(OSSTask *uploadPartTask) {
            NSLog(@"objectKey: %@", uploadPart.objectkey);
            if (!uploadPartTask.error) {
                OSSUploadPartResult * result = uploadPartTask.result;
                
                NSLog(@"+++++++++++++++ %d", i);
                
                uint64_t fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:uploadPart.uploadPartFileURL.absoluteString error:nil] fileSize];
                @synchronized (_partInfos) { // NSMutableArray 是线程不安全的，所以加个同步锁
                    OSSPartInfo *partInfo = [OSSPartInfo partInfoWithPartNum:i eTag:result.eTag size:fileSize];
                    NSLog(@"分片 part的标示：**************  %d", partInfo.partNum);
                    [_partInfos addObject:partInfo];
                }
                dispatch_group_leave(group);
                
            } else {
                NSLog(@"upload part error: %@", uploadPartTask.error);
                dispatch_group_leave(group);
            }
            return nil;
        }];
        
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"分片上传完成!  %@", _partInfos);
        // 对异步上传的part进行排序
        [self sortPart];
        [self ossComplete];
    });
    
}

- (void)listPart {
    // 罗列分片
    OSSListPartsRequest * listParts = [OSSListPartsRequest new];
    listParts.bucketName = bucketName;
    listParts.objectKey = multipartUploadKey;
    listParts.uploadId = _uploadId;
    
    OSSTask * listPartTask = [_client listParts:listParts];
    
    [listPartTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            NSLog(@"list part result success!");
            OSSListPartsResult * listPartResult = task.result;
            for (NSDictionary * partInfo in listPartResult.parts) {
                NSLog(@"each part: %@", partInfo);
            }
        } else {
            NSLog(@"list part result error: %@", task.error);
        }
        return nil;
    }];
}

- (void)sortPart {
    for(int i=0; i<_partInfos.count; i++){
        for(int j=i; j<_partInfos.count; j++){
            OSSPartInfo *iPartInfo = _partInfos[i];
            OSSPartInfo *jPartInfo = _partInfos[j];
            
            if(iPartInfo.partNum > jPartInfo.partNum){
                [_partInfos exchangeObjectAtIndex:i withObjectAtIndex:j];
            }
        }
    }
}

- (void)ossComplete{
    // 上传完成
    OSSCompleteMultipartUploadRequest * complete = [OSSCompleteMultipartUploadRequest new];
    complete.bucketName = bucketName;
    complete.objectKey = multipartUploadKey;
    complete.uploadId = _uploadId;
    complete.partInfos = _partInfos;
    
    OSSTask * completeTask = [_client completeMultipartUpload:complete];
    
    [[completeTask continueWithBlock:^id(OSSTask *task) {
        if (!task.error) {
            OSSCompleteMultipartUploadResult * result = task.result;
            dispatch_async(dispatch_get_main_queue(), ^{
                _textView.text = [NSString stringWithFormat:@"分片上传成功  result ++++ :  %@", result];
            });
            
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                _textView.text = [NSString stringWithFormat:@"分片上传失败  error：------ %@", task.error];
            });
            
        }
        return nil;
    }] waitUntilFinished];
}

@end
