//
//  TICDSFileManagerBasedWholeStoreDownloadOperation.m
//  ShoppingListMac
//
//  Created by Tim Isted on 26/04/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#import "TICoreDataSync.h"


@implementation TICDSFileManagerBasedWholeStoreDownloadOperation

- (void)checkForMostRecentClientWholeStore
{
    NSError *anyError = nil;
    NSArray *clientIdentifiers = [self contentsOfDirectoryAtPath:[self thisDocumentWholeStoreDirectoryPath] error:&anyError];
    
    if( !clientIdentifiers ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        [self determinedMostRecentWholeStoreWasUploadedByClientWithIdentifier:nil];
        return;
    }
    
    NSString *identifierToReturn = nil;
    NSDate *latestModificationDate = nil;
    NSDate *eachModificationDate = nil;
    NSDictionary *attributes = nil;
    for( NSString *eachIdentifier in clientIdentifiers ) {
        if( [[eachIdentifier substringToIndex:1] isEqualToString:@"."] ) {
            continue;
        }
        
        attributes = [self attributesOfItemAtPath:[self pathToWholeStoreFileForClientWithIdentifier:eachIdentifier] error:&anyError];
        
        if( !attributes ) {
            continue;
        }
        
        eachModificationDate = [attributes valueForKey:NSFileModificationDate];
        
        if( !latestModificationDate ) {
            latestModificationDate = eachModificationDate;
            identifierToReturn = eachIdentifier;
            continue;
        } else if( [eachModificationDate compare:latestModificationDate] == NSOrderedDescending ) {
            latestModificationDate = eachModificationDate;
            identifierToReturn = eachIdentifier;
        }
    }
    
    if( !identifierToReturn && anyError ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        [self determinedMostRecentWholeStoreWasUploadedByClientWithIdentifier:nil];
        return;
    }
    
    if( !identifierToReturn ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeNoPreviouslyUploadedStoreExists classAndMethod:__PRETTY_FUNCTION__]];
        [self determinedMostRecentWholeStoreWasUploadedByClientWithIdentifier:nil];
        return;
    }
    
    [self determinedMostRecentWholeStoreWasUploadedByClientWithIdentifier:identifierToReturn];
}

- (void)syncFileURL:(NSURL *)url
{
    NSNumber *isUbiquitousNumber;
    BOOL success = [url getResourceValue:&isUbiquitousNumber forKey:NSURLIsUbiquitousItemKey error:NULL];
    if ( !success ) return;
    if ( !isUbiquitousNumber.boolValue ) return;
    
    NSError *error;
    BOOL downloaded = NO, downloading = YES;
    while ( !downloaded ) {
        NSNumber *downloadedNumber;
        BOOL success = [url getResourceValue:&downloadedNumber forKey:NSURLUbiquitousItemIsDownloadedKey error:&error];
        if ( !success ) return;        
        downloaded = downloadedNumber.boolValue;
        
        NSNumber *downloadingNumber;
        success = [url getResourceValue:&downloadingNumber forKey:NSURLUbiquitousItemIsDownloadingKey error:&error];
        if ( !success ) return;
        downloading = downloadingNumber.boolValue;
        
        if ( !downloading && !downloaded ) {
            BOOL success = [self.fileManager startDownloadingUbiquitousItemAtURL:url error:&error];
            if ( !success ) return;
        }
        
        [NSThread sleepForTimeInterval:0.1];
    }
}

- (void)syncDirectoryURL:(NSURL *)url
{
    NSString *path = url.path;
    
    NSNumber *isUbiquitousNumber;
    BOOL success = [url getResourceValue:&isUbiquitousNumber forKey:NSURLIsUbiquitousItemKey error:NULL];
    if ( !success ) return;
    if ( !isUbiquitousNumber.boolValue ) return;

    [self syncFileURL:url];
    NSArray *subPaths = [self.fileManager contentsOfDirectoryAtPath:url.path error:NULL];
    for ( NSString *subPath in subPaths ) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSString *fullPath = [path stringByAppendingPathComponent:subPath];
        NSURL *subURL = [NSURL fileURLWithPath:fullPath];
        NSDictionary *attributes = [self.fileManager attributesOfItemAtPath:fullPath error:NULL];
        NSString *fileType = [attributes objectForKey:NSFileType];
        [self syncFileURL:subURL];
        if ( [fileType isEqualToString:NSFileTypeDirectory] ) {
            [self syncDirectoryURL:subURL];
        }
        [pool drain];
    }
}

- (void)downloadWholeStoreFile
{
    NSError *anyError = nil;
    BOOL success = YES;
    NSString *wholeStorePath = [self pathToWholeStoreFileForClientWithIdentifier:[self requestedWholeStoreClientIdentifier]];
    NSURL *storeURL = [NSURL fileURLWithPath:wholeStorePath];
    
    // Make sure the store and related files are downloaded when using iCloud
    BOOL isDir;
    if ( [self.fileManager fileExistsAtPath:wholeStorePath isDirectory:&isDir] ) {
        if ( isDir )
            [self syncDirectoryURL:storeURL];
        else
            [self syncFileURL:storeURL];
    }
    
    if( ![self shouldUseEncryption] ) {
        // just copy the file straight across
        success = [self copyItemAtPath:wholeStorePath toPath:[[self localWholeStoreFileLocation] path] error:&anyError];
        
        if( !success ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        }
        
        [self downloadedWholeStoreFileWithSuccess:success];
        return;
    }
    
    // otherwise, copy the file to temp location, and decrypt it
    NSString *tmpStorePath = [[self tempFileDirectoryPath] stringByAppendingPathComponent:[wholeStorePath lastPathComponent]];
    
    success = [self copyItemAtPath:wholeStorePath toPath:tmpStorePath error:&anyError];
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        [self downloadedWholeStoreFileWithSuccess:success];
        return;
    }
    
    success = [[self cryptor] decryptFileAtLocation:[NSURL fileURLWithPath:wholeStorePath] writingToLocation:[self localWholeStoreFileLocation] error:&anyError];
    
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeEncryptionError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
    }
    
    [self downloadedWholeStoreFileWithSuccess:success];
}

- (void)downloadAppliedSyncChangeSetsFile
{
    if( ![self fileExistsAtPath:[self pathToAppliedSyncChangesFileForClientWithIdentifier:[self requestedWholeStoreClientIdentifier]]] ) {
        [self downloadedAppliedSyncChangeSetsFileWithSuccess:YES];
        return;
    }
    
    NSError *anyError = nil;
    BOOL success = [self copyItemAtPath:[self pathToAppliedSyncChangesFileForClientWithIdentifier:[self requestedWholeStoreClientIdentifier]] toPath:[[self localAppliedSyncChangeSetsFileLocation] path] error:&anyError];
    
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
    }
    
    [self downloadedAppliedSyncChangeSetsFileWithSuccess:success];
}

- (void)fetchRemoteIntegrityKey
{
    NSString *integrityDirectoryPath = [[self thisDocumentDirectoryPath] stringByAppendingPathComponent:TICDSIntegrityKeyDirectoryName];
    
    NSError *anyError = nil;
    NSArray *contents = [self contentsOfDirectoryAtPath:integrityDirectoryPath error:&anyError];
    
    if( !contents ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        [self fetchedRemoteIntegrityKey:nil];
        return;
    }
    
    for( NSString *eachFile in contents ) {
        if( [eachFile length] < 5 ) {
            continue;
        }
        
        [self fetchedRemoteIntegrityKey:eachFile];
        return;
    }
    
    [self fetchedRemoteIntegrityKey:nil];
}

#pragma mark -
#pragma mark Paths
- (NSString *)pathToWholeStoreFileForClientWithIdentifier:(NSString *)anIdentifier
{
    return [[[self thisDocumentWholeStoreDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSWholeStoreFilename];
}

- (NSString *)pathToAppliedSyncChangesFileForClientWithIdentifier:(NSString *)anIdentifier
{
    return [[[self thisDocumentWholeStoreDirectoryPath] stringByAppendingPathComponent:anIdentifier] stringByAppendingPathComponent:TICDSAppliedSyncChangeSetsFilename];
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (void)dealloc
{
    [_thisDocumentDirectoryPath release], _thisDocumentDirectoryPath = nil;
    [_thisDocumentWholeStoreDirectoryPath release], _thisDocumentWholeStoreDirectoryPath = nil;
    
    [super dealloc];
}

#pragma mark -
#pragma mark Properties
@synthesize thisDocumentDirectoryPath = _thisDocumentDirectoryPath;
@synthesize thisDocumentWholeStoreDirectoryPath = _thisDocumentWholeStoreDirectoryPath;

@end
