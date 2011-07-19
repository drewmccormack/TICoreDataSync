//
//  TICDSApplicationSyncManager.h
//  ShoppingListMac
//
//  Created by Tim Isted on 21/04/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#import "TICDSClassesAndProtocols.h"
#import "TICDSTypesAndEnums.h"

/** `TICDSDocumentSyncManager` describes the generic behavior provided by an Application Sync Manager in the `TICoreDataSync` framework.
 
 The Application Sync Manager is responsible for application-wide synchronization settings. You typically have only one in an application.
 
 Don't instantiate this class directly, but instead use one of the subclasses:
 
 1. `TICDSFileManagerBasedApplicationSyncManager`
 2. `TICDSDropboxSDKBasedApplicationSyncManager`
 
 @warning You must register the application sync manager before you can use it to perform any other tasks, or register any documents.
*/

@interface TICDSApplicationSyncManager : NSObject <TICDSApplicationRegistrationOperationDelegate, TICDSDocumentDeletionOperationDelegate> {
@private
    TICDSApplicationSyncManagerState _state;
    
    BOOL _shouldUseEncryption;
    
    id <TICDSApplicationSyncManagerDelegate> _delegate;
    NSString *_appIdentifier;
    NSString *_clientIdentifier;
    NSString *_clientDescription;
    NSDictionary *_applicationUserInfo;
    
    NSOperationQueue *_registrationQueue;
    NSOperationQueue *_otherTasksQueue;
    
    NSFileManager *_fileManager;
}

#pragma mark - Application-Wide Sync Manager
/** @name Application-Wide Sync Manager */

/** Returns an application-wide sync manager.
 
 Use this method to get the default application sync manager. If this is the first time you've requested one, a new one will be created. 
 
 @return The default application-wide sync manager (if one doesn't exist, it will be created).
 
 @warning Don't call this method on `TICDSApplicationSyncManager`; if you do, you'll receive a generic application sync manager object. Instead call it on one of the subclasses, for example `[TICDSFileManagerBasedApplicationSyncManager defaultSyncManager]`.
 */
+ (id)defaultApplicationSyncManager;

/** Set the application-wide sync manager.
 
 Use this method if you need to release an existing default manager, or wish to use a different default one for some reason.
 
 @param aSyncManager The new sync manager to set as the application-wide default. */
+ (void)setDefaultApplicationSyncManager:(TICDSApplicationSyncManager *)aSyncManager;

#pragma mark - Registration
/** @name Registration */

/** Register an application ready for future synchronization.
 
 Use this method to register the sync manager ready for document registration and synchronization (via `TICDSDocumentSyncManager` objects).
 
 This will automatically spawn a `TICDSApplicationRegistrationOperation`, and notify you of progress through the `TICDSApplicationSyncManagerDelegate` methods.
 
 If this is the first time you have registered a client with this app identifier, registration will automatically create the file structure necessary at the remote end for this and other clients to synchronize. See `[TICDSUtilities remoteGlobalAppDirectoryHierarchy]` for the structure that will be created.
 
 @param aDelegate The object you wish to be notified regarding application-related sync information; this object must conform to the `TICDSApplicationSyncManagerDelegate` protocol, which includes some required methods.
 @param anAppIdentifier The identification string used to identify the synchronization information across multiple clients. If you wish to be able to synchronize Mac and iOS, this app identifier should be the same on both platforms. This identifier will also be used as the root level of the remote file structure.
 @param aClientIdentifier An identification string for this client. Every client wishing to synchronize must have a string to identify itself (i.e., the application instance on a machine) uniquely. You would typically create a UUID string the first time your app is launched and store this in preferences.
 @param aClientDescription A human-readable string used to identify this client, e.g. the computer name.
 @param someUserInfo A dictionary of information that will be saved throughout all future synchronizations. Because this information is saved in a plist, everything in the dictionary must be archivable.
 
 @warning You must call this method before using the application sync manager for any other purpose. */
- (void)registerWithDelegate:(id <TICDSApplicationSyncManagerDelegate>)aDelegate globalAppIdentifier:(NSString *)anAppIdentifier uniqueClientIdentifier:(NSString *)aClientIdentifier description:(NSString *)aClientDescription userInfo:(NSDictionary *)someUserInfo;

/** Continue registering an application for the first time specifying whether to use encryption, or an existing application that requires an encryption password.
 
 If you are requesting the registration process continue for a **new** application, and do not want to enable encryption, specify `nil` for the password, otherwise supply the password the user wishes to use.
 
 If you are requesting the registration process continue for an **existing** application that requires an encryption password, you must specify a password other than `nil`.
 
 @param aPassword The password to use, or `nil` to specify no encryption on a new application registration. */
- (void)continueRegisteringWithEncryptionPassword:(NSString *)aPassword;

/** Cancel registration after being asked for an encryption password.
 
 Use this method to cancel registration if the user is unable to provide the correct encryption password.
 
 @warning Using this method at other times will result in undefined behavior. */
- (void)cancelRegistrationWithoutProvidingEncryptionPassword;

#pragma mark - Previously Synchronized Documents
/** @name Accessing Previously Synchronized Documents */

/** Request a list of documents that have previously been synchronized for this application, by any client.
 
 This method will automatically spawn a `TICDSListOfPreviouslySynchronizedDocumentsOperation`, and notify you of progress through the `TICDSApplicationSyncManagerDelegate` methods. */
- (void)requestListOfPreviouslySynchronizedDocuments;

/** Download a document that has previously been synchronized for this application.
 
 This method will automatically spawn a `TICDSDocumentDownloadOperation`, and notify you of progress through the `TICDSApplicationSyncManagerDelegate` methods.
 
 @param anIdentifier The unique synchronization identifier string for the requested document. If you're requesting the download of a document represented by a dictionary supplied from a request for the list of previously synchronized documents, use the value for its `kTICDSDocumentIdentifier` key.
 @param aLocation The location on disc to which the persistent store file should be downloaded. */
- (void)requestDownloadOfDocumentWithIdentifier:(NSString *)anIdentifier toLocation:(NSURL *)aLocation;

#pragma mark - Client Information
/** @name Accessing Client Information */

/** Request a list of clients that are registered to synchronize with this application.
 
 This method returns a dictionary containing as keys the client identifiers, and as values the `deviceInfo.plist` information. If you specify `YES` for `includeDocuments`, each dictionary will also include an array containing the identifiers of documents for which the client is registered.
 
 @param includeDocuments `YES` if the request should also include a list of documents that each client is registered to synchronize, otherwise `NO`. */
- (void)requestListOfSynchronizedClientsIncludingDocuments:(BOOL)includeDocuments;

#pragma mark - Deleting Documents
/** @name Deleting Documents */

/** Delete the specified document, if it exists, from the remote.
 
 As well as delegate methods indicating the status of the overall deletion process, `applicationSyncManager:willDeleteDirectoryForDocumentWithIdentifier:` and `applicationSyncManager:didDeleteDirectoryForDocumentWithIdentifier:` methods will be called either side of the deletion of the actual document directory.
 
 @param anIdentifier The identifier of the document to be deleted. */
- (void)deleteDocumentWithIdentifier:(NSString *)anIdentifier;

#pragma mark - Overridden Methods
/** @name Methods Overridden by Subclasses */

/** Returns an application registration operation.
 
 Subclasses of `TICDSApplicationSyncManager` use this method to return a correctly-configured application registration operation for their particular sync method.
 
 @return A correctly-configured subclass of `TICDSApplicationRegistrationOperation`.
*/
- (TICDSApplicationRegistrationOperation *)applicationRegistrationOperation;

/** Returns an operation to fetch a list of previously synchronized documents.
 
 Subclasses of `TICDSApplicationSyncManager` use this method to return a correctly-configured list of documents operation for their particular sync method.
 
 @return A correctly-configured subclass of `TICDSListOfPreviouslySynchronizedDocumentsOperation`. */
- (TICDSListOfPreviouslySynchronizedDocumentsOperation *)listOfPreviouslySynchronizedDocumentsOperation;

/** Returns an operation to download a document with a given identifier.
 
 Subclasses of `TICDSApplicationSyncManager` use this method to return a correctly-configured whole store download operation for their particular sync method.
 
 @param anIdentifier The unique synchronization identifier of the document to download.
 
 @return A correctly-configured subclass of `TICDSWholeStoreDownloadOperation`. */
- (TICDSWholeStoreDownloadOperation *)wholeStoreDownloadOperationForDocumentWithIdentifier:(NSString *)anIdentifier;

/** Returns an operation to fetch a list of registered clients for an application.
 
 Subclasses of `TICDSApplicationSyncManager` use this method to return a correctly-configured operation for their particular sync method.
 
 @return A correctly-configured subclass of `TICDSListOfApplicationRegisteredClientsOperation`. */
- (TICDSListOfApplicationRegisteredClientsOperation *)listOfApplicationRegisteredClientsOperation;

/** Returns an operation to delete a document with a given identifier.
 
 Subclasses of `TICDSApplicationSyncManager` use this method to return a correctly-configured document deletion operation for their particular sync method.
 
 @param anIdentifier The unique synchronization identifier of the document to delete.
 
 @return A correctly-configured subclass of `TICDSDocumentDeletionOperation`. */
- (TICDSDocumentDeletionOperation *)documentDeletionOperationForDocumentWithIdentifier:(NSString *)anIdentifier;

#pragma mark - Properties
/** @name Properties */

/** Application Sync Manager State.

 The state of the application sync manager indicates whether it is ready to synchronize.
 
 Possible values are defined in `TICDSTypesAndEnums.h`.
 */
@property (nonatomic, readonly) TICDSApplicationSyncManagerState state;

/** Used to indicate whether the application sync manager should use encryption for the remote files.
 
 This value is set automatically during the application registration process. */
@property (nonatomic, assign) BOOL shouldUseEncryption;

/** The Application Sync Manager Delegate. */
@property (nonatomic, assign) id <TICDSApplicationSyncManagerDelegate> delegate;

/** The App Identifier used for registration.
 
 Set the identifier when registering with `registerWithDelegate:globalAppIdentifier:uniqueClientIdentifier:description:userInfo:`.
 */
@property (nonatomic, readonly, retain) NSString *appIdentifier;

/** The Client Identifier used for registration.
 
 Set the identifier when registering with `registerWithDelegate:globalAppIdentifier:uniqueClientIdentifier:description:userInfo:`.
 */
@property (nonatomic, readonly, retain) NSString *clientIdentifier;

/** The Client Description used for registration.
 
 Set the description when registering with `registerWithDelegate:globalAppIdentifier:uniqueClientIdentifier:description:userInfo:`.
 */
@property (nonatomic, readonly, retain) NSString *clientDescription;

/** The User Info used for registration.
 
 Set the user info when registering with `registerWithDelegate:globalAppIdentifier:uniqueClientIdentifier:description:userInfo:`.
 */
@property (nonatomic, readonly, retain) NSDictionary *applicationUserInfo;

/** A File Manager for use by the application sync manager. */
@property (nonatomic, readonly, retain) NSFileManager *fileManager;

#pragma mark - Operation Queues
/** @name Operation Queues */

/** The operation queue used for registration operations. */
@property (nonatomic, readonly, retain) NSOperationQueue *registrationQueue;

/** The operation queue used for non-registration tasks.
 
 The queue is suspended until registration has completed successfully. */
@property (nonatomic, readonly, retain) NSOperationQueue *otherTasksQueue;

#pragma mark - Relative Paths
/** @name Relative Paths */

/** The path to the `Documents` directory, relative to the root of the remote file structure. */
@property (nonatomic, readonly) NSString *relativePathToDocumentsDirectory;

/** The path to the `Information` directory, relative to the root of the remote file structure. */
@property (nonatomic, readonly) NSString *relativePathToInformationDirectory;

/** The path to the `DeletedDocuments` directory inside the `Information` directory, relative ot the root of the remote file structure. */
@property (nonatomic, readonly) NSString *relativePathToInformationDeletedDocumentsDirectory;

/** The path to the `Encryption` directory, relative to the root of the remote file structure. */
@property (nonatomic, readonly) NSString *relativePathToEncryptionDirectory;

/** The path to the `salt.ticdsync` file inside the `Encryption` directory, relative to the root of the remote file structure. */
@property (nonatomic, readonly) NSString *relativePathToEncryptionDirectorySaltDataFilePath;

/** The path to the `test.ticdsync` file inside the `Encryption` directory, relative to the rot of the remote file structure. */
@property (nonatomic, readonly) NSString *relativePathToEncryptionDirectoryTestDataFilePath;

/** The path to the `ClientDevices` directory, relative to the root of the remote file structure. */
@property (nonatomic, readonly) NSString *relativePathToClientDevicesDirectory;

/** The path to this client's directory inside the `ClientDevices` directory, relative to the root of the remote file structure. */
@property (nonatomic, readonly) NSString *relativePathToClientDevicesThisClientDeviceDirectory;

/** The path to a document's directory within the `Documents` directory, relative to the root of the remote file structure.
 
 @param anIdentifier The unique sync identifier of the document. */
- (NSString *)relativePathToDocumentDirectoryForDocumentWithIdentifier:(NSString *)anIdentifier;

/** The path to a document's `WholeStore` directory, relative to the root of the remote file structure.
 
 @param anIdentifier The unique sync identifier of the document. */
- (NSString *)relativePathToWholeStoreDirectoryForDocumentWithIdentifier:(NSString *)anIdentifier;

@end
