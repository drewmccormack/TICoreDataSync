//
//  TICDSOperation.m
//  ShoppingListMac
//
//  Created by Tim Isted on 21/04/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#import "TICoreDataSync.h"


@implementation TICDSOperation

#pragma mark -
#pragma mark Primary Operation
- (void)start
{
    if( [self needsMainThread] && ![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
        return;
    } else if( ![self needsMainThread] && [NSThread isMainThread] ) {
        [self performSelectorInBackground:@selector(start) withObject:nil];
        return;
    }
    
    // Configure the Cryptor object, if encryption is enabled
    if( [self shouldUseEncryption] ) {
        FZACryptor *aCryptor = [[FZACryptor alloc] init];
        [self setCryptor:aCryptor];
        [aCryptor release];
    }

    [self operationDidStart];
    
    if( [self isCancelled] ) {
        [self operationWasCancelled];
        return;
    }
    
    [self main];
}

- (void)main
{
    [self setError:[TICDSError errorWithCode:TICDSErrorCodeMethodNotOverriddenBySubclass classAndMethod:__PRETTY_FUNCTION__]];
    
    [self operationDidFailToComplete];
}

#pragma mark -
#pragma mark Operation Settings
- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)needsMainThread
{
    return NO;
}

#pragma mark -
#pragma mark Completion
- (void)endExecution
{
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (void)ticdPrivate_operationDidCompleteSuccessfully:(BOOL)success cancelled:(BOOL)wasCancelled
{
    // cleanup temporary directory, if necessary
    if( _tempFileDirectoryPath ) {
        [self removeItemAtPath:_tempFileDirectoryPath error:NULL];
    }
    
    if( success ) {
        TICDSLog(TICDSLogVerbosityStartAndEndOfMainOperationPhase, @"TICDSOperation completed successfully");
        [self ti_alertDelegateOnMainThreadWithSelector:@selector(operationCompletedSuccessfully:) waitUntilDone:YES];
    } else if( wasCancelled ) {
        TICDSLog(TICDSLogVerbosityStartAndEndOfMainOperationPhase, @"TICDSOperation was cancelled");
        [self ti_alertDelegateOnMainThreadWithSelector:@selector(operationWasCancelled:) waitUntilDone:YES];
    } else {
        TICDSLog(TICDSLogVerbosityStartAndEndOfMainOperationPhase, @"TICDSOperation failed to complete");
        [self ti_alertDelegateOnMainThreadWithSelector:@selector(operationFailedToComplete:) waitUntilDone:YES];
    }
    
    // This is a nasty way to, I think, avoid a problem with the DropboxSDK on iOS - must revisit and sort out soon
    if( [NSThread isMainThread] ) {
        [self performSelector:@selector(endExecution) withObject:nil afterDelay:0.1];
    } else {
        [self endExecution];
    }
}

- (void)operationDidStart
{
    TICDSLog(TICDSLogVerbosityStartAndEndOfMainOperationPhase, @"TICDSOperation started");
    
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)operationDidCompleteSuccessfully
{
    [self ticdPrivate_operationDidCompleteSuccessfully:YES cancelled:NO];
}

- (void)operationDidFailToComplete
{
    [self ticdPrivate_operationDidCompleteSuccessfully:NO cancelled:NO];
}

- (void)operationWasCancelled
{
    [self ticdPrivate_operationDidCompleteSuccessfully:NO cancelled:YES];
}

#pragma mark -
#pragma mark Lazy Accessors
- (NSFileManager *)fileManager
{
    if( _fileManager ) return _fileManager;
    
    _fileManager = [[NSFileManager alloc] init];
    
    return _fileManager;
}

- (NSFileCoordinator *)fileCoordinator
{
    if( _fileCoordinator ) return _fileCoordinator;
    
    _fileCoordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
    
    return _fileCoordinator;
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (id)initWithDelegate:(NSObject <TICDSOperationDelegate> *)aDelegate
{
    self = [super init];
    if( !self ) return nil;
    
    _delegate = aDelegate;
    
    _isExecuting = NO;
    _isFinished = NO;
    
    return self;
}

- (void)dealloc
{
    [_cryptor release], _cryptor = nil;
    [_userInfo release], _userInfo = nil;
    [_error release], _error = nil;
    [_clientIdentifier release], _clientIdentifier = nil;
    [_fileManager release], _fileManager = nil;
    [_fileCoordinator release], _fileCoordinator = nil;
    [_tempFileDirectoryPath release], _tempFileDirectoryPath = nil;

    [super dealloc];
}

#pragma mark -
#pragma mark Lazy Accessors
- (NSString *)tempFileDirectoryPath
{
    if( _tempFileDirectoryPath ) {
        return _tempFileDirectoryPath;
    }
    
    NSString *aDirectoryPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[TICDSUtilities uuidString]];
    
    NSError *anyError = nil;
    BOOL success = [[self fileManager] createDirectoryAtPath:aDirectoryPath withIntermediateDirectories:NO attributes:nil error:&anyError];
    
    if( !success ) {
        TICDSLog(TICDSLogVerbosityErrorsOnly, @"Internal error: unable to create temp file directory");
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
    }
    
    _tempFileDirectoryPath = [aDirectoryPath retain];
    
    return _tempFileDirectoryPath;
}

#pragma mark -
#pragma mark Coordinated I/O

- (BOOL)copyItemAtPath:(NSString *)fromPath toPath:(NSString *)toPath error:(NSError **)error
{
    __block NSError *anyError = nil;
    NSURL *readURL = [NSURL fileURLWithPath:fromPath];
    NSURL *writeURL = [NSURL fileURLWithPath:toPath];
    __block BOOL success = NO;
    [self.fileCoordinator coordinateReadingItemAtURL:readURL options:0 writingItemAtURL:writeURL options:NSFileCoordinatorWritingForReplacing error:&anyError byAccessor:^(NSURL *newReadingURL, NSURL *newWritingURL) {
        success = [[self fileManager] copyItemAtURL:newReadingURL toURL:newWritingURL error:&anyError];
    }];
    if ( error ) *error = anyError;
    return success;
}

- (BOOL)moveItemAtPath:(NSString *)fromPath toPath:(NSString *)toPath error:(NSError **)error
{
    __block NSError *anyError = nil;
    NSURL *fromURL = [NSURL fileURLWithPath:fromPath];
    NSURL *toURL = [NSURL fileURLWithPath:toPath];
    __block BOOL success = NO;    
    [self.fileCoordinator coordinateReadingItemAtURL:fromURL options:0 writingItemAtURL:toURL options:NSFileCoordinatorWritingForReplacing error:&anyError byAccessor:^(NSURL *newFromURL, NSURL *newToURL) {
        success = [[self fileManager] moveItemAtURL:newFromURL toURL:newToURL error:&anyError];
        [self.fileCoordinator itemAtURL:newFromURL didMoveToURL:newToURL];
    }];
    if ( error ) *error = anyError;
    return success;
}

- (BOOL)removeItemAtPath:(NSString *)fromPath error:(NSError **)error
{
    NSURL *fromURL = [NSURL fileURLWithPath:fromPath];
    __block BOOL success = NO;
    __block NSError *anyError = nil;
    [self.fileCoordinator coordinateWritingItemAtURL:fromURL options:NSFileCoordinatorWritingForDeleting error:&anyError byAccessor:^(NSURL *newURL) {
        success = [[self fileManager] removeItemAtURL:newURL error:&anyError];
    }];
    if ( error ) *error = anyError;
    return success;
}

- (BOOL)fileExistsAtPath:(NSString *)fromPath
{
    NSURL *fromURL = [NSURL fileURLWithPath:fromPath];
    __block BOOL result = NO;
    [self.fileCoordinator coordinateReadingItemAtURL:fromURL options:NSFileCoordinatorReadingWithoutChanges error:NULL byAccessor:^(NSURL *newURL) {
        result = [[self fileManager] fileExistsAtPath:newURL.path];
    }];
    return result;
}

- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error
{
    NSURL *url = [NSURL fileURLWithPath:path];
    __block BOOL success = NO;
    __block NSError *anyError = nil;
    [self.fileCoordinator coordinateWritingItemAtURL:url options:NSFileCoordinatorWritingForReplacing error:&anyError byAccessor:^(NSURL *newURL) {
        success = [[self fileManager] createDirectoryAtPath:newURL.path withIntermediateDirectories:createIntermediates attributes:attributes error:&anyError];
    }];
    if ( error ) *error = anyError;
    return success;
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error
{
    NSURL *url = [NSURL fileURLWithPath:path];
    __block NSError *anyError;
    __block NSArray *result = nil;
    [self.fileCoordinator coordinateReadingItemAtURL:url options:0 error:&anyError byAccessor:^(NSURL *newURL) {
        result = [[self fileManager] contentsOfDirectoryAtPath:newURL.path error:&anyError];
    }];
    if ( error ) *error = anyError;
    return result;
}

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error
{
    NSURL *url = [NSURL fileURLWithPath:path];
    __block NSError *anyError;
    __block NSDictionary *result = nil;
    [self.fileCoordinator coordinateReadingItemAtURL:url options:0 error:&anyError byAccessor:^(NSURL *newURL) {
        result = [[self fileManager] attributesOfItemAtPath:newURL.path error:&anyError];
    }];
    if ( error ) *error = anyError;
    return result;
}

-(BOOL)writeData:(NSData *)data toFile:(NSString *)path error:(NSError **)error
{
    NSURL *url = [NSURL fileURLWithPath:path];
    __block BOOL success = NO;
    __block NSError *anyError = nil;
    [self.fileCoordinator coordinateWritingItemAtURL:url options:NSFileCoordinatorWritingForReplacing error:&anyError byAccessor:^(NSURL *newURL) {
        success = [data writeToFile:newURL.path options:0 error:&anyError];
    }];
    if ( error ) *error = anyError;
    return success;
}

-(BOOL)writeObject:(id)object toFile:(NSString *)path
{
    NSURL *url = [NSURL fileURLWithPath:path];
    __block BOOL success = NO;
    __block NSError *anyError = nil;
    [self.fileCoordinator coordinateWritingItemAtURL:url options:NSFileCoordinatorWritingForReplacing error:&anyError byAccessor:^(NSURL *newURL) {
        success = [object writeToFile:newURL.path atomically:NO];
    }];
    return success;
}

-(NSData *)dataWithContentsOfFile:(NSString *)path error:(NSError **)error
{
    NSURL *url = [NSURL fileURLWithPath:path];
    __block NSError *anyError;
    __block NSData *result = nil;
    [self.fileCoordinator coordinateReadingItemAtURL:url options:0 error:&anyError byAccessor:^(NSURL *newURL) {
        result = [NSData dataWithContentsOfFile:newURL.path options:0 error:&anyError];
    }];
    if ( error ) *error = anyError;
    return result;
}

-(id)readObjectFromFile:(NSString *)path
{
    NSURL *url = [NSURL fileURLWithPath:path];
    __block NSError *anyError;
    __block id result = nil;
    [self.fileCoordinator coordinateReadingItemAtURL:url options:0 error:&anyError byAccessor:^(NSURL *newURL) {
        NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:newURL.path];
        result = [NSPropertyListSerialization propertyListWithStream:stream options:0 format:0 error:&anyError];
    }];
    return result;
}

#pragma mark -
#pragma mark Properties
@synthesize shouldUseEncryption = _shouldUseEncryption;
@synthesize cryptor = _cryptor;
@synthesize delegate = _delegate;
@synthesize userInfo = _userInfo;
@synthesize isExecuting = _isExecuting;
@synthesize isFinished = _isFinished;
@synthesize error = _error;
@synthesize fileManager = _fileManager;
@synthesize fileCoordinator = _fileCoordinator;
@synthesize tempFileDirectoryPath = _tempFileDirectoryPath;
@synthesize clientIdentifier = _clientIdentifier;

@end
