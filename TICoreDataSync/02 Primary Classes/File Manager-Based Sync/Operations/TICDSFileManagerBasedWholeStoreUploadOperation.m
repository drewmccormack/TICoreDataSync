//
//  TICDSFileManagerBasedWholeStoreUploadOperation.m
//  ShoppingListMac
//
//  Created by Tim Isted on 25/04/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#import "TICoreDataSync.h"


@implementation TICDSFileManagerBasedWholeStoreUploadOperation

- (void)checkWhetherThisClientTemporaryWholeStoreDirectoryExists
{
    TICDSRemoteFileStructureExistsResponseType status = [self fileExistsAtPath:[self thisDocumentTemporaryWholeStoreThisClientDirectoryPath]] ? TICDSRemoteFileStructureExistsResponseTypeDoesExist : TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
    
    [self discoveredStatusOfThisClientTemporaryWholeStoreDirectory:status];
}

- (void)deleteThisClientTemporaryWholeStoreDirectory
{
    NSError *anyError = nil;
    
    BOOL success = [self removeItemAtPath:[self thisDocumentTemporaryWholeStoreThisClientDirectoryPath] error:&anyError];
    
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
    }
    
    [self deletedThisClientTemporaryWholeStoreDirectoryWithSuccess:success];
}

- (void)createThisClientTemporaryWholeStoreDirectory
{
    NSError *anyError = nil;
    
    BOOL success = [self createDirectoryAtPath:[self thisDocumentTemporaryWholeStoreThisClientDirectoryPath] withIntermediateDirectories:YES attributes:nil error:&anyError];
    
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
    }
    
    [self createdThisClientTemporaryWholeStoreDirectoryWithSuccess:success];
}

// This method de-dupes external binaries to save space
-(BOOL)copyLocalWholeStoreAtPath:(NSString *)localPath toTemporaryWholeStoreAtPath:(NSString *)tempPath error:(NSError **)error
{
    if ( error ) *error = nil;
    
    static NSString * const externalBinarySubDir = @".Data_SUPPORT/_EXTERNAL_DATA";
    NSString *localStoreExtDir = [localPath stringByAppendingPathComponent:externalBinarySubDir];
    BOOL hasExternalBinaries = [self.fileManager fileExistsAtPath:localStoreExtDir];
    if ( !hasExternalBinaries ) return [self copyItemAtPath:localPath toPath:tempPath error:error];
    
    NSString *remoteStore = [self thisDocumentWholeStoreThisClientDirectoryPath];
    NSString *remoteSharedExtDir = [remoteStore stringByAppendingPathComponent:@"../SharedExternalData"];
    
    NSArray *externalFiles = [self.fileManager contentsOfDirectoryAtPath:localStoreExtDir error:error];
    if ( !externalFiles ) return NO;
    
    // Determine the list of remote shared external binaries
    NSArray *remoteSharedExtFiles = nil;
    if ( [self fileExistsAtPath:remoteSharedExtDir] ) {
        remoteSharedExtFiles = [self contentsOfDirectoryAtPath:remoteSharedExtDir error:error];
        if ( !remoteSharedExtFiles ) return NO;
    }
    else {
        remoteSharedExtFiles = @[];
    }
    
    // First copy everything to the temp dir, and then remove what is not needed
    if ( ![self copyItemAtPath:localPath toPath:tempPath error:error] ) return NO;
    
    // Create the temporary shared directory
    NSString *tempSharedExtDir = [tempPath stringByAppendingPathComponent:@"../SharedExternalData"];
    [self.fileManager removeItemAtPath:tempSharedExtDir error:NULL];
    if ( ![self.fileManager createDirectoryAtPath:tempSharedExtDir withIntermediateDirectories:YES attributes:nil error:error] ) return NO;
    
    // Now go through external binaries, remove what isn't needed, and move others to shared dir
    NSString *tempStoreExtDir = [tempPath stringByAppendingPathComponent:externalBinarySubDir];
    NSSet *localSet = [NSSet setWithArray:externalFiles];
    NSSet *remoteSet = [NSSet setWithArray:remoteSharedExtFiles];
    NSMutableArray *extFilenames = [NSMutableArray array];
    for ( NSString *filename in localSet ) {
        if ( [filename hasPrefix:@"."] ) continue;

        NSString *tempStoreFile = [tempStoreExtDir stringByAppendingPathComponent:filename];        
        NSDictionary *attributes = [self.fileManager attributesOfItemAtPath:tempStoreFile error:NULL];
        if ( ![attributes[NSFileType] isEqualToString:NSFileTypeRegular] ) continue;
        
        if ( ![remoteSet containsObject:filename] ) {
            // Haven't got this file yet. Move to shared temporary directory.
            NSString *tempSharedFile = [tempSharedExtDir stringByAppendingPathComponent:filename];
            if ( ![self.fileManager moveItemAtPath:tempStoreFile toPath:tempSharedFile error:error] ) return NO;
        }
        else {
            [self.fileManager removeItemAtPath:tempStoreFile error:NULL];
        }
        
        [extFilenames addObject:filename];
    }
    
    // Add manifest file
    NSString *manifestFile = [tempStoreExtDir stringByAppendingPathComponent:@"manifest.plist"];
    if ( ![extFilenames writeToFile:manifestFile atomically:NO] ) return NO;
    
    return YES;
}

- (void)uploadLocalWholeStoreFileToThisClientTemporaryWholeStoreDirectory
{
    NSError *anyError = nil;
    BOOL success = YES;
    NSString *filePath = [[self localWholeStoreFileLocation] path];
    
    if( [self shouldUseEncryption] ) {
        BOOL isDir;
        NSAssert( [self.fileManager fileExistsAtPath:filePath isDirectory:&isDir] && !isDir, @"Encryption not supported when whole store is directory.");
        
        NSString *tempPath = [[self tempFileDirectoryPath] stringByAppendingPathComponent:[filePath lastPathComponent]];
        
        success = [[self cryptor] encryptFileAtLocation:[NSURL fileURLWithPath:filePath] writingToLocation:[NSURL fileURLWithPath:tempPath] error:&anyError];
        if( !success ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeEncryptionError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
            [self uploadedWholeStoreFileToThisClientTemporaryWholeStoreDirectoryWithSuccess:NO];
            return;
        }
        
        filePath = tempPath;
    }
    
    success = [self copyLocalWholeStoreAtPath:filePath toTemporaryWholeStoreAtPath:[self thisDocumentTemporaryWholeStoreThisClientDirectoryWholeStoreFilePath] error:&anyError];
    
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
    }
    
    [self uploadedWholeStoreFileToThisClientTemporaryWholeStoreDirectoryWithSuccess:success];
}

- (void)uploadLocalAppliedSyncChangeSetsFileToThisClientTemporaryWholeStoreDirectory
{
    NSError *anyError = nil;
    
    BOOL success = [self copyItemAtPath:[[self localAppliedSyncChangeSetsFileLocation] path] toPath:[self thisDocumentTemporaryWholeStoreThisClientDirectoryAppliedSyncChangeSetsFilePath] error:&anyError];
    
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
    }
    
    [self uploadedAppliedSyncChangeSetsFileToThisClientTemporaryWholeStoreDirectoryWithSuccess:success];
}

- (void)checkWhetherThisClientWholeStoreDirectoryExists
{
    TICDSRemoteFileStructureExistsResponseType status = [self fileExistsAtPath:[self thisDocumentWholeStoreThisClientDirectoryPath]] ? TICDSRemoteFileStructureExistsResponseTypeDoesExist : TICDSRemoteFileStructureExistsResponseTypeDoesNotExist;
    
    [self discoveredStatusOfThisClientWholeStoreDirectory:status];
}

- (void)deleteThisClientWholeStoreDirectory
{
    NSError *anyError = nil;
    
    BOOL success = [self removeItemAtPath:[self thisDocumentWholeStoreThisClientDirectoryPath] error:&anyError];
    
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
    }
    
    [self deletedThisClientWholeStoreDirectoryWithSuccess:success];
}

- (void)copyThisClientTemporaryWholeStoreDirectoryToThisClientWholeStoreDirectory
{
    NSError *anyError = nil;
    
    // Move store
    BOOL success = [self moveItemAtPath:[self thisDocumentTemporaryWholeStoreThisClientDirectoryPath] toPath:[self thisDocumentWholeStoreThisClientDirectoryPath] error:&anyError];
    if( !success ) {
        [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
        [self copiedThisClientTemporaryWholeStoreDirectoryToThisClientWholeStoreDirectoryWithSuccess:NO];
        return;
    }
    
    // Transfer shared external binaries
    // Get shared data location
    NSString *tempSharedExtDir = [[self thisDocumentTemporaryWholeStoreThisClientDirectoryPath] stringByAppendingPathComponent:@"../SharedExternalData"];
    tempSharedExtDir = [tempSharedExtDir stringByStandardizingPath];
    if ( [self.fileManager fileExistsAtPath:tempSharedExtDir] ) {
        // Create remote shared dir if needed
        NSString *remoteStore = [self thisDocumentWholeStoreThisClientDirectoryPath];
        NSString *remoteSharedExtDir = [remoteStore stringByAppendingPathComponent:@"../SharedExternalData"];
        if ( ![self fileExistsAtPath:remoteSharedExtDir] ) {
            if ( ![self createDirectoryAtPath:remoteSharedExtDir withIntermediateDirectories:YES attributes:nil error:&anyError] ) {
                [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
                [self copiedThisClientTemporaryWholeStoreDirectoryToThisClientWholeStoreDirectoryWithSuccess:NO];
                return;
            }
        }
        
        // Move files
        NSArray *contents = [self.fileManager contentsOfDirectoryAtPath:tempSharedExtDir error:&anyError];
        BOOL success = contents != nil;
        if ( !success ) {
            [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
            [self copiedThisClientTemporaryWholeStoreDirectoryToThisClientWholeStoreDirectoryWithSuccess:NO];
            return;
        }
        
        for ( NSString *filename in contents ) {
            NSString *tempPath = [tempSharedExtDir stringByAppendingPathComponent:filename];
            NSString *remotePath = [remoteSharedExtDir stringByAppendingPathComponent:filename];
            if ( ![self moveItemAtPath:tempPath toPath:remotePath error:&anyError] ) {
                [self setError:[TICDSError errorWithCode:TICDSErrorCodeFileManagerError underlyingError:anyError classAndMethod:__PRETTY_FUNCTION__]];
                [self copiedThisClientTemporaryWholeStoreDirectoryToThisClientWholeStoreDirectoryWithSuccess:NO];
                return;
            }
        }
    }
    
    [self copiedThisClientTemporaryWholeStoreDirectoryToThisClientWholeStoreDirectoryWithSuccess:YES];
}

#pragma mark -
#pragma mark Initialization and Deallocation
- (void)dealloc
{
    [_thisDocumentTemporaryWholeStoreThisClientDirectoryPath release], _thisDocumentTemporaryWholeStoreThisClientDirectoryPath = nil;
    [_thisDocumentTemporaryWholeStoreThisClientDirectoryWholeStoreFilePath release], _thisDocumentTemporaryWholeStoreThisClientDirectoryWholeStoreFilePath = nil;
    [_thisDocumentTemporaryWholeStoreThisClientDirectoryAppliedSyncChangeSetsFilePath release], _thisDocumentTemporaryWholeStoreThisClientDirectoryAppliedSyncChangeSetsFilePath = nil;
    [_thisDocumentWholeStoreThisClientDirectoryPath release], _thisDocumentWholeStoreThisClientDirectoryPath = nil;

    [super dealloc];
}

#pragma mark -
#pragma mark Properties
@synthesize thisDocumentTemporaryWholeStoreThisClientDirectoryPath = _thisDocumentTemporaryWholeStoreThisClientDirectoryPath;
@synthesize thisDocumentTemporaryWholeStoreThisClientDirectoryWholeStoreFilePath = _thisDocumentTemporaryWholeStoreThisClientDirectoryWholeStoreFilePath;
@synthesize thisDocumentTemporaryWholeStoreThisClientDirectoryAppliedSyncChangeSetsFilePath = _thisDocumentTemporaryWholeStoreThisClientDirectoryAppliedSyncChangeSetsFilePath;
@synthesize thisDocumentWholeStoreThisClientDirectoryPath = _thisDocumentWholeStoreThisClientDirectoryPath;

@end
