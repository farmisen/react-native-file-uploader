//
// Copyright © 2016 Fabrice Armisen <farmisen@gmail.com>
// This program is free software. It comes without any warranty, to
// the extent permitted by applicable law. You can redistribute it and/or modify 
// it under the terms of the Do What The Fuck You Want To Public License, Version 2,
// as published by Sam Hocevar. See http://www.wtfpl.net/ for more details.
//
// Inspired by https://github.com/kamilkp/react-native-file-transfer
//

#import "RCTFileUploader.h"
#import "RCTUtils.h"
#import "RCTEventDispatcher.h"

static NSString *const URI_FIELD = @"uri";
static NSString *const METHOD_FIELD = @"method";
static NSString *const UPLOAD_URL_FIELD = @"uploadUrl";
static NSString *const CONTENT_TYPE_FIELD = @"contentType";
static NSString *const FILE_NAME_FIELD = @"fileName";
static NSString *const FIELD_NAME_FIELD = @"fieldName";

static NSString *const TWO_HYPHENS = @"--";
static NSString *const LINE_END = @"\r\n";

@interface RCTFileUploader () <NSURLSessionDelegate, NSURLSessionTaskDelegate>
@end

@implementation RCTFileUploader {
    NSMutableDictionary *_bytesSent;
}


RCT_EXPORT_MODULE()

- (instancetype)init {
    self = [super init];
    if (self) {
        _bytesSent = [NSMutableDictionary dictionary];
    }
    
    return self;
};

@synthesize bridge = _bridge;

RCT_EXPORT_METHOD(upload:
                  (NSDictionary *) settings
                  callback:
                  (RCTResponseSenderBlock) callback) {
    NSString *uri = settings[URI_FIELD];
    if ([uri hasPrefix:@"file:"]) {
        [self uploadUri:settings callback:callback];
    }
    else if ([uri isAbsolutePath]) {
        [self uploadFile:settings callback:callback];
    }
    else {
        callback(@[RCTMakeError([NSString stringWithFormat:@"Can't handle %@", uri], nil, nil)]);
    }
}

#pragma private

- (void)uploadFile:(NSDictionary *)settings callback:(RCTResponseSenderBlock)callback {
    NSError *error;
    NSData *data = [NSData dataWithContentsOfFile:settings[URI_FIELD] options:NSDataReadingMappedIfSafe error:&error];
    if (error) {
        callback(@[RCTMakeError([error localizedDescription], nil, nil)]);
    } else {
        [self uploadData:data settings:settings callback:callback];
    }
    
}

- (void)uploadUri:(NSDictionary *)settings callback:(RCTResponseSenderBlock)callback {
    NSURL *url = [NSURL URLWithString:settings[URI_FIELD]];
    NSError *error;
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:&error];
    if (error) {
        callback(@[RCTMakeError([error localizedDescription], nil, nil)]);
    } else {
        [self uploadData:data settings:settings callback:callback];
    }
}

- (void)uploadData:(NSData *)data settings:(NSDictionary *)settings callback:(RCTResponseSenderBlock)callback {
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:settings[UPLOAD_URL_FIELD]]];
    
    NSString *boundary = [NSString stringWithFormat:@"****%@****", [[NSUUID UUID] UUIDString]];
    
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [request setHTTPShouldHandleCookies:NO];
    [request setTimeoutInterval:60];
    
    [request setHTTPMethod:settings[METHOD_FIELD] ?: @"POST"];
    [request setValue:@"Keep-Alive" forHTTPHeaderField:@"Connection"];
    [request setValue:@"React Native File Uploader iOS HTTP Client" forHTTPHeaderField:@"User-Agent"];
    [request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
    
    NSString *contentType = settings[CONTENT_TYPE_FIELD] ?: @"application/octet-stream";
    NSString *filename = settings[FILE_NAME_FIELD] ?: [self filenameForContentType:contentType];
    NSString *fieldName = settings[FIELD_NAME_FIELD];
    
    NSMutableData *body = [NSMutableData data];
    [self append:[NSString stringWithFormat:@"%@%@%@", TWO_HYPHENS, boundary, LINE_END] to:body];
    [self append:[NSString stringWithFormat:@"Content-Disposition: form-data; name=%@; filename=%@%@", fieldName, filename, LINE_END] to:body];
    [self append:[NSString stringWithFormat:@"Content-Type: %@%@", contentType, LINE_END] to:body];
    [self append:[NSString stringWithFormat:@"Content-Transfer-Encoding: binary%@", LINE_END] to:body];
    
    [self append:LINE_END to:body];
    [body appendData:data];
    [self append:LINE_END to:body];
    
    NSDictionary *extraData = settings[@"data"];
    for (NSString *field in [extraData allKeys]) {
        [self append:[NSString stringWithFormat:@"%@%@%@", TWO_HYPHENS, boundary, LINE_END] to:body];
        [self append:[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"%@", field, LINE_END] to:body];
        [self append:[NSString stringWithFormat:@"Content-Type: text/plain%@", LINE_END] to:body];
        [self append:[NSString stringWithFormat:@"%@%@%@", LINE_END, extraData[field], LINE_END] to:body];
    }
    
    [self append:[NSString stringWithFormat:@"%@%@%@%@", TWO_HYPHENS, boundary, TWO_HYPHENS, LINE_END] to:body];
    
    NSString *postLength = [NSString stringWithFormat:@"%d", (int) [body length]];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.HTTPMaximumConnectionsPerHost = 1;
    NSURLSession *upLoadSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    
    NSURLSessionUploadTask *task = [upLoadSession uploadTaskWithRequest:request fromData:body completionHandler:^(NSData *responseData, NSURLResponse *response, NSError *error) {
        if (error) {
            callback(@[RCTMakeError([error localizedDescription], nil, nil)]);
        } else {
            NSInteger statusCode = [(NSHTTPURLResponse *) response statusCode];
            NSString *responseBody = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            NSDictionary *result = @{
                                     @"status" : @(statusCode),
                                     @"data" : responseBody};
            callback(@[[NSNull null], result]);
        }
    }
                                    ];
    task.taskDescription = settings[URI_FIELD];
    _bytesSent[settings[URI_FIELD]] = @(0);
    [task resume];
}

#pragma helpers

- (void)append:(NSString *)string to:(NSMutableData *)data {
    [data appendData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (NSString *)filenameForContentType:(NSString *)contentType {
    NSArray *components = [contentType componentsSeparatedByString:@"/"];
    NSString *extension = [components count] == 2
    ? [NSString stringWithFormat:@".%@", components[1]]
    : @"";
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyyMMddhhmmss"];
    
    return [NSString stringWithFormat:@"%@%@", [dateFormatter stringFromDate:[NSDate date]], extension];
}


#pragma NSURLSessionDataDelegate

#pragma NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    int64_t sent = [_bytesSent[task.taskDescription] longLongValue];
    sent = sent + bytesSent;
    _bytesSent[task.taskDescription] = @(sent);
    
    [self.bridge.eventDispatcher sendDeviceEventWithName:@"fileUploadProgress"
                                                    body:@{
                                                           @"uri" : task.taskDescription,
                                                           @"sent" : [@(sent) stringValue],
                                                           @"expectedToSend" : [@(totalBytesExpectedToSend) stringValue]}];
}


@end
