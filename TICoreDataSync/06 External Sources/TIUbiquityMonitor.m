// Copyright (c) 2013 Drew McCormack
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "TIUbiquityMonitor.h"

@implementation TIUbiquityMonitor {
    NSMetadataQuery *metadataQuery;
    NSMutableDictionary *downloadingBytesByURL, *uploadingBytesByURL;
    void (^progressCallbackBlock)(long long toDownload, long long toUpload);
    BOOL isMonitoring;
}

@synthesize ubiquitousBytesToDownload = ubiquitousBytesToDownload;
@synthesize ubiquitousBytesToUpload = ubiquitousBytesToUpload;
@synthesize predicate = predictate;

#pragma mark Initialization and Deallocation

- (id)initWithPredicate:(NSPredicate *)newPredicate
{
    self = [super init];
    if ( self ) {
        predictate = [newPredicate retain];
        progressCallbackBlock = NULL;
        isMonitoring = NO;
        metadataQuery = nil;
        downloadingBytesByURL = uploadingBytesByURL = nil;
        ubiquitousBytesToUpload = ubiquitousBytesToDownload = 0;
    }
    return self;
}

- (id)init
{
    NSPredicate *newPredicate = [NSPredicate predicateWithFormat:@"%K like '*'", NSMetadataItemFSNameKey];
    return [self initWithPredicate:newPredicate];
}

- (void)dealloc
{
    [self stopMonitoring];
    [predictate release], predictate = nil;
    [super dealloc];
}

#pragma mark Controlling Monitoring

- (void)startMonitoringWithProgressBlock:(void(^)(long long toDownload, long long toUpload))block
{
    if ( isMonitoring ) @throw [NSException exceptionWithName:@"TIException" reason:@"Attempt to start monitoring in a TIUbiquityMonitor that is already monitoring" userInfo:nil];
    
    isMonitoring = YES;
    
    progressCallbackBlock = [block copy];
    downloadingBytesByURL = [[NSMutableDictionary alloc] initWithCapacity:200];
    uploadingBytesByURL = [[NSMutableDictionary alloc] initWithCapacity:200];

    metadataQuery = [[NSMetadataQuery alloc] init];
    metadataQuery.notificationBatchingInterval = 1.0;
    metadataQuery.searchScopes = [NSArray arrayWithObject:NSMetadataQueryUbiquitousDataScope];
    metadataQuery.predicate = predictate;
    
    NSNotificationCenter *notifationCenter = [NSNotificationCenter defaultCenter];
    [notifationCenter addObserver:self selector:@selector(update:) name:NSMetadataQueryDidFinishGatheringNotification object:metadataQuery];
    [notifationCenter addObserver:self selector:@selector(update:) name:NSMetadataQueryDidUpdateNotification object:metadataQuery];
    
    [metadataQuery startQuery];
}

- (void)stopMonitoring
{
    [metadataQuery disableUpdates];

    isMonitoring = NO;
    [downloadingBytesByURL release], downloadingBytesByURL = nil;
    [uploadingBytesByURL release], uploadingBytesByURL = nil;
        
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSMetadataQueryDidFinishGatheringNotification object:metadataQuery];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSMetadataQueryDidUpdateNotification object:metadataQuery];
    
    [metadataQuery stopQuery];
    [metadataQuery release], metadataQuery = nil;
    
    // Release callback last, because it could be retaining objects
    [progressCallbackBlock autorelease], progressCallbackBlock = nil;
}

- (void)update:(NSNotification *)notif
{
    [metadataQuery disableUpdates];
    
    NSUInteger count = [metadataQuery resultCount];
    for ( NSUInteger i = 0; i < count; i++ ) {
        NSURL *url = [metadataQuery valueOfAttribute:NSMetadataItemURLKey forResultAtIndex:i];

        // Remove any existing contribution to the bytes counts from a previous update
        ubiquitousBytesToDownload -= [downloadingBytesByURL[url] longLongValue];
        ubiquitousBytesToUpload -= [uploadingBytesByURL[url] longLongValue];

        [downloadingBytesByURL removeObjectForKey:url];
        [uploadingBytesByURL removeObjectForKey:url];
        
        NSNumber *percentDownloaded = [metadataQuery valueOfAttribute:NSMetadataUbiquitousItemPercentDownloadedKey forResultAtIndex:i];
        NSNumber *percentUploaded = [metadataQuery valueOfAttribute:NSMetadataUbiquitousItemPercentUploadedKey forResultAtIndex:i];;
        NSNumber *downloaded = [metadataQuery valueOfAttribute:NSMetadataUbiquitousItemIsDownloadedKey forResultAtIndex:i];
        NSNumber *uploaded = [metadataQuery valueOfAttribute:NSMetadataUbiquitousItemIsUploadedKey forResultAtIndex:i];
        NSNumber *fileSizeNumber = [metadataQuery valueOfAttribute:NSMetadataItemFSSizeKey forResultAtIndex:i];

        unsigned long long fileSize = fileSizeNumber.unsignedLongLongValue;
        if ( downloaded && !downloaded.boolValue ) {
            double percentage = percentDownloaded ? percentDownloaded.doubleValue : 100.0;
            long long fileDownloadSize = percentage / 100.0 * fileSize;
            ubiquitousBytesToDownload += fileDownloadSize;
            downloadingBytesByURL[url] = @(fileDownloadSize);
        }
        else if ( uploaded && !uploaded.boolValue ) {
            double percentage = percentUploaded ? percentUploaded.doubleValue : 100.0;
            long long fileDownloadSize = percentage / 100.0 * fileSize;
            ubiquitousBytesToUpload += fileDownloadSize;
            uploadingBytesByURL[url] = @(fileDownloadSize);
        }
    }
    
    if ( progressCallbackBlock ) progressCallbackBlock(ubiquitousBytesToDownload, ubiquitousBytesToUpload);
    
    [metadataQuery enableUpdates];
}

@end

