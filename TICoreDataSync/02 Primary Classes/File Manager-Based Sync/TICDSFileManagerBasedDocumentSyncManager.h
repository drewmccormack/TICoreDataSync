//
//  TICDSFileManagerBasedDocumentSyncManager.h
//  ShoppingListMac
//
//  Created by Tim Isted on 22/04/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#import "TICDSDocumentSyncManager.h"

/** The `TICDSFileManagerBasedDocumentSyncManager` describes a class used to synchronize documents with a remote service that can be accessed via an `NSFileManager`. This includes:
 
 1. Dropbox on the desktop (files are typically accessed via `~/Dropbox`)
 2. iDisk on the desktop
 
 No FileManagerBased-specific settings are required when you create a `TICDSFileManagerBasedDocumentSyncManager`--the `applicationDirectoryPath` is set automatically when you register (based on the properties set on the `TICDSFileManagerBasedApplicationSyncManager`).
 
 One **additional feature** is provided by an `NSFileManager`-based document sync manager---the ability to trigger a synchronization whenever changes are detected in other clients' `SyncChanges` directories. To make use of this functionality, simply call the `enableAutomaticSynchronizationAfterChangesDetectedFromOtherClients` method once the document has been registered.
 */
@interface TICDSFileManagerBasedDocumentSyncManager : TICDSDocumentSyncManager {
@private
    NSString *_applicationDirectoryPath;
    
    TIKQDirectoryWatcher *_directoryWatcher;
    NSMutableArray *_watchedClientDirectoryIdentifiers;
    
    NSString *_tempDirectoryPath;
}

/** @name Automatic Change Detection */

/** Configures the FileManager-based document sync manager to watch for changes uploaded by other clients, and initiate a sync operation automatically when new changes are detected. */
- (void)enableAutomaticSynchronizationAfterChangesDetectedFromOtherClients;

/** @name Properties */

/** A `TIKQDirectoryWatcher` used to watch for changes in the `SyncChanges` directories for this document. */
@property (nonatomic, readonly) TIKQDirectoryWatcher *directoryWatcher;

/** A mutable array containing the identifiers of clients currently being watched. */
@property (nonatomic, readonly) NSMutableArray *watchedClientDirectoryIdentifiers;

/** @name Paths */

/** The path to the root of the application. This will be set automatically when you register and supply a `TICDSFileManagerBasedApplicationSyncManager`. */
@property (nonatomic, retain) NSString *applicationDirectoryPath;

/** The path to the `ClientDevices` directory. */
@property (nonatomic, readonly) NSString *clientDevicesDirectoryPath;

/** The path to this document's `identifier.plist` file inside the `DeletedDocuments` directory. */
@property (nonatomic, readonly) NSString *deletedDocumentsThisDocumentIdentifierPlistPath;

/** The path to the `Documents` directory. */
@property (nonatomic, readonly) NSString *documentsDirectoryPath;

/** The path to this document's directory inside the `Documents` directory. */
@property (nonatomic, readonly) NSString *thisDocumentDirectoryPath;

/** The path to this document's `DeletedClients` directory. */
@property (nonatomic, readonly) NSString *thisDocumentDeletedClientsDirectoryPath;

/** The path to this document's `SyncChanges` directory. */
@property (nonatomic, readonly) NSString *thisDocumentSyncChangesDirectoryPath;

/** The path to this client's directory inside this document's `SyncChanges` directory. */
@property (nonatomic, readonly) NSString *thisDocumentSyncChangesThisClientDirectoryPath;

/** The path to this document's `SyncCommands` directory. */
@property (nonatomic, readonly) NSString *thisDocumentSyncCommandsDirectoryPath;

/** The path to this client's directory inside this document's `SyncCommands` directory. */
@property (nonatomic, readonly) NSString *thisDocumentSyncCommandsThisClientDirectoryPath;

/** The path to this client's temporary `WholeStore` directory. */
@property (nonatomic, readonly) NSString *thisDocumentTemporaryWholeStoreThisClientDirectoryPath;

/** The path to this client's temporary `WholeStore.ticdsync` file. */
@property (nonatomic, readonly) NSString *thisDocumentTemporaryWholeStoreFilePath;

/** The path to this client's temporary `AppliedSyncChangeSets.ticdsync` file. */
@property (nonatomic, readonly) NSString *thisDocumentTemporaryAppliedSyncChangeSetsFilePath;

/** The path to this document's `WholeStore` directory. */
@property (nonatomic, readonly) NSString *thisDocumentWholeStoreDirectoryPath;

/** The path to this client's directory inside this document's `WholeStore` directory. */
@property (nonatomic, readonly) NSString *thisDocumentWholeStoreThisClientDirectoryPath;

/** The path to this client's `WholeStore.ticdsync` file. */
@property (nonatomic, readonly) NSString *thisDocumentWholeStoreFilePath;

/** The path to this client's `AppliedSyncChangeSets.ticdsync` file. */
@property (nonatomic, readonly) NSString *thisDocumentAppliedSyncChangeSetsFilePath;

/** The path to this document's `RecentSyncs` directory. */
@property (nonatomic, readonly) NSString *thisDocumentRecentSyncsDirectoryPath;

/** The path to this client's RecentSync file inside this document's `RecentSyncs` directory. */
@property (nonatomic, readonly) NSString *thisDocumentRecentSyncsThisClientFilePath;

@end
