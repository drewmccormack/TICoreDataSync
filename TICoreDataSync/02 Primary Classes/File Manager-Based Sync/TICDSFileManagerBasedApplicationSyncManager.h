//
//  TICDSFileManagerBasedApplicationSyncManager.h
//  ShoppingListMac
//
//  Created by Tim Isted on 22/04/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#import "TICDSApplicationSyncManager.h"

/** Notification that fires when the cloud transfer progress properties have been refreshed. */
extern NSString * const TICDSApplicationSyncManagerDidRefreshCloudTransferProgressNotification;

/** The `TICDSFileManagerBasedApplicationSyncManager` describes a class used to synchronize an application with a remote service that can be accessed via an `NSFileManager`. This includes:
 
 1. Dropbox on the desktop (files are typically accessed via `~/Dropbox`)
 2. iDisk on the desktop
 
 The only requirement is that you set the `NSURL` location of the directory that should contain the application *before* you register the sync manager. For example, if you wish to have sync information stored in `~/Dropbox/com.timisted.MySynchronizedApp/`, specify `~/Dropbox` as the `applicationContainingDirectoryLocation`.
 */

@interface TICDSFileManagerBasedApplicationSyncManager : TICDSApplicationSyncManager {
@private
    NSURL *_applicationContainingDirectoryLocation;
    NSMetadataQuery *_cloudMetadataQuery;
    NSMetadataQuery *_transferProgressMetadataQuery;
    NSMetadataQuery *_downloadMetadataQuery;
    void (^_downloadProgressBlock)(BOOL complete, long long remainingBytes, BOOL *stop);
}

@property (readonly) unsigned long long cloudBytesToUpload, cloudBytesToDownload;

#pragma mark iCloud-Related Methods

/** Start a new metadata query to asynchronously download cloud files not yet local. */
- (void)refreshCloudMetadataQuery;

/** Use a metadata query to download all data from the cloud. */
- (void)downloadAllCloudData:(void(^)(BOOL complete, long long remainingBytes, BOOL *stop))block;

/** Start a metadata query to scan iCloud files, and determine how much data still needs to be uploaded and downloaded.
    Access the results using the provided properties. Use the notification to determine when the asynchronous
    calculation is finished. */
- (void)refreshCloudTransferProgress;

#pragma mark Dropbox-Related Methods
/** @name Dropbox-Related Methods */

/** Returns the location of the user's Dropbox directory, if one exists, by decoding the content in `~/.dropbox/host.db`, as described at https://www.dropbox.com/developers/desktop_apps.
 
 @return The location of the user's Dropbox directory, or `nil` if no path could be found.
 
 @warning This procedure has been marked "will likely be deprecated" by Dropbox. Do not rely on this as the only way to get hold of the user's Dropbox directory, and do not use it without checking with the user that it is the correct location. */
+ (NSURL *)localDropboxDirectoryLocation;

/** @name Properties */

/** The location of the directory that should contain the file structure for this application's synchronization. */
@property (nonatomic, retain) NSURL *applicationContainingDirectoryLocation;

/** @name Paths */

/** The path to the root application directory. */
@property (nonatomic, readonly) NSString *applicationDirectoryPath;

/** The path to the `DeletedDocuments` directory inside the `Information` directory at the root of the application. */
@property (nonatomic, readonly) NSString *deletedDocumentsDirectoryPath;

/** The path to the `salt.ticdsync` file inside the `Encryption` directory at the root of the application. */
@property (nonatomic, readonly) NSString *encryptionDirectorySaltDataFilePath;

/** The path to the `test.ticdsync` file inside the `Encryption` directory at the root of the application. */
@property (nonatomic, readonly) NSString *encryptionDirectoryTestDataFilePath;

/** The path to the `Documents` directory at the root of the application. */
@property (nonatomic, readonly) NSString *documentsDirectoryPath;

/** The path to the `ClientDevices` directory at the root of the application. */
@property (nonatomic, readonly) NSString *clientDevicesDirectoryPath;

/** The path to this client's directory inside the `ClientDevices` directory at the root of the application. */
@property (nonatomic, readonly) NSString *clientDevicesThisClientDeviceDirectoryPath;

/** The path to the `WholeStore` directory for a document with a given identifier.
 
 @param anIdentifier The unique sync identifier of the document. */
- (NSString *)pathToWholeStoreDirectoryForDocumentWithIdentifier:(NSString *)anIdentifier;

@end
