//
//  TICDSSynchronizedManagedObject.m
//  ShoppingListMac
//
//  Created by Tim Isted on 23/04/2011.
//  Copyright 2011 Tim Isted. All rights reserved.
//

#import "TICoreDataSync.h"

@interface TICDSSynchronizedManagedObject ()

- (TICDSSyncChange *)createSyncChangeForChangeType:(TICDSSyncChangeType)aType;
- (void)createSyncChangesForAllRelationships;
- (void)createSyncChangeIfApplicableForRelationship:(NSRelationshipDescription *)aRelationship;
- (void)createToOneRelationshipSyncChange:(NSRelationshipDescription *)aRelationship;
- (void)createToManyRelationshipSyncChanges:(NSRelationshipDescription *)aRelationship;
- (NSDictionary *)dictionaryOfAllAttributes;

@end

@implementation TICDSSynchronizedManagedObject

@synthesize excludeFromSync;

#pragma mark -
#pragma mark Primary Sync Change Creation

+ (NSSet *)keysForWhichSyncChangesWillNotBeCreated
{
    return nil;
}

- (void)createSyncChangeForInsertion
{
    // changedAttributes = a dictionary containing the values of _all_ the object's attributes at time it was saved
    // this method also creates extra sync changes for _all_ the object's relationships 
    
    TICDSSyncChange *syncChange = [self createSyncChangeForChangeType:TICDSSyncChangeTypeObjectInserted];
    
    TICDSLog(TICDSLogVerbosityManagedObjectOutput, @"[%@] %@", syncChange.objectSyncID, [self class]);
    
    [syncChange setChangedAttributes:[self dictionaryOfAllAttributes]];
    [self createSyncChangesForAllRelationships];
}

- (void)createSyncChangeForDeletion
{
    if ([TICDSChangeIntegrityStoreManager containsDeletionRecordForObjectID:[self objectID]]) {
        [TICDSChangeIntegrityStoreManager removeObjectIDFromDeletionIntegrityStore:[self objectID]];
        return;
    }

    // nothing is stored in changedAttributes or changedRelationships at this time
    // if a conflict is encountered, the deletion will have to take precedent, resurrection is not possible
    [self createSyncChangeForChangeType:TICDSSyncChangeTypeObjectDeleted];
}

- (void)createSyncChangesForChangedProperties
{
    // separate sync changes are created for each property change, whether it be relationship or attribute
    NSDictionary *changedValues = [self changedValues];
    
    NSSet *propertyNamesToBeIgnored = [[self class] keysForWhichSyncChangesWillNotBeCreated];
    NSDictionary *relationshipsByName = [[NSDictionary alloc] initWithDictionary:[[self entity] relationshipsByName]];
    NSDictionary *attributesByName = [[NSDictionary alloc] initWithDictionary:[[self entity] attributesByName]];
    for( NSString *eachPropertyName in changedValues ) {
        if (propertyNamesToBeIgnored != nil && [propertyNamesToBeIgnored containsObject:eachPropertyName]) {
            TICDSLog(TICDSLogVerbosityManagedObjectOutput, @"Not creating a change for %@.%@", [self class], eachPropertyName);
            continue;
        }
        
        NSRelationshipDescription *relationship = [relationshipsByName objectForKey:eachPropertyName];
        NSAttributeDescription *attribute = [attributesByName objectForKey:eachPropertyName];
        if ( relationship && !relationship.isTransient ) {
            [self createSyncChangeIfApplicableForRelationship:relationship];
        }
        else if ( attribute && !attribute.isTransient ) {
            TICDSSyncChange *syncChange = [self createSyncChangeForChangeType:TICDSSyncChangeTypeAttributeChanged];
            TICDSLog(TICDSLogVerbosityManagedObjectOutput, @"[%@] %@", syncChange.objectSyncID, [self class]);
            [syncChange setRelevantKey:eachPropertyName];
            id eachValue = [self transformedValueOfAttribute:eachPropertyName];
            [syncChange setChangedAttributes:eachValue];
        }
    }
    [relationshipsByName release];
    [attributesByName release];
}

#pragma mark -
#pragma mark Sync Change Helper Methods
- (TICDSSyncChange *)createSyncChangeForChangeType:(TICDSSyncChangeType)aType
{
    TICDSSyncChange *syncChange = [TICDSSyncChange syncChangeOfType:aType inManagedObjectContext:[self syncChangesMOC]];
    
    TICDSLog(TICDSLogVerbosityManagedObjectOutput, @"[%@] %@", syncChange.objectSyncID, [self class]);

    [syncChange setObjectSyncID:[self valueForKey:TICDSSyncIDAttributeName]];
    [syncChange setObjectEntityName:[[self entity] name]];
    [syncChange setLocalTimeStamp:[NSDate date]];
    [syncChange setRelevantManagedObject:self];
    
    return syncChange;
}

- (void)createSyncChangesForAllRelationships
{
    NSDictionary *objectRelationshipsByName = [[self entity] relationshipsByName];
    
    for( NSString *eachRelationshipName in objectRelationshipsByName ) {
        [self createSyncChangeIfApplicableForRelationship:[objectRelationshipsByName valueForKey:eachRelationshipName]];
    }
}

- (void)createSyncChangeIfApplicableForRelationship:(NSRelationshipDescription *)aRelationship
{
    NSRelationshipDescription *inverseRelationship = [aRelationship inverseRelationship];
    
    // Each check makes sure there _is_ an inverse relationship before checking its type, to allow for relationships with no inverse set
    
    // Check if this is a many-to-one relationship (only sync the -to-one side)
    if( ([aRelationship isToMany]) && inverseRelationship && (![inverseRelationship isToMany]) ) {
        return;
    }
    
    // Check if this is a many to many relationship, and only sync the first relationship name alphabetically
    if( ([aRelationship isToMany]) && inverseRelationship && ([inverseRelationship isToMany]) && ([[aRelationship name] caseInsensitiveCompare:[inverseRelationship name]] == NSOrderedDescending) ) {
        return;
    }
    
    // Check if this is a one to one relationship, and only sync the first relationship name alphabetically
    if( (![aRelationship isToMany]) && inverseRelationship && (![inverseRelationship isToMany]) && ([[aRelationship name] caseInsensitiveCompare:[inverseRelationship name]] == NSOrderedDescending) ) {
        return;
    }
    
    // Check if this is a self-referential relationship, and only sync one side, somehow!!!
    
    // If we get here, this is:
    // a) a one-to-many relationship
    // b) the alphabetically lower end of a many-to-many relationship
    // c) the alphabetically lower end of a one-to-one relationship
    // d) edge-case 1: a many-to-many relationship with the same relationship name at both ends (will currently create 2 sync changes)
    // e) edge-case 2: a one-to-one relationship with the same relationship name at both ends (will currently create 2 sync changes)
    
    if( ![aRelationship isToMany] ) {
        [self createToOneRelationshipSyncChange:aRelationship];
    } else {
        [self createToManyRelationshipSyncChanges:aRelationship];
    }
}

- (void)createToOneRelationshipSyncChange:(NSRelationshipDescription *)aRelationship
{
    TICDSSyncChange *syncChange = [self createSyncChangeForChangeType:TICDSSyncChangeTypeToOneRelationshipChanged];
    
    TICDSLog(TICDSLogVerbosityManagedObjectOutput, @"[%@] %@", syncChange.objectSyncID, [self class]);

    [syncChange setRelatedObjectEntityName:[[aRelationship destinationEntity] name]];
    [syncChange setRelevantKey:[aRelationship name]];
    
    NSManagedObject *relatedObject = [self valueForKey:[aRelationship name]];
    
    // Check that the related object should be synchronized
    if( [relatedObject isKindOfClass:[TICDSSynchronizedManagedObject class]] ) {
        [syncChange setChangedRelationships:[relatedObject valueForKey:TICDSSyncIDAttributeName]];
    }
}

- (void)createToManyRelationshipSyncChanges:(NSRelationshipDescription *)aRelationship
{
    NSSet *relatedObjects = [self valueForKey:[aRelationship name]];
    NSDictionary *committedValues = [self committedValuesForKeys:[NSArray arrayWithObject:[aRelationship name]]];
    
    NSSet *previouslyRelatedObjects = [committedValues valueForKey:[aRelationship name]];
    
    NSMutableSet *addedObjects = [NSMutableSet setWithCapacity:5];
    for( NSManagedObject *eachObject in relatedObjects ) {
        if( ![previouslyRelatedObjects containsObject:eachObject] ) {
            [addedObjects addObject:eachObject];
        }
    }
    
    NSMutableSet *removedObjects = [NSMutableSet setWithCapacity:5];
    for( NSManagedObject *eachObject in previouslyRelatedObjects ) {
        if( ![relatedObjects containsObject:eachObject] ) {
            [removedObjects addObject:eachObject];
        }
    }
    
    TICDSSyncChange *eachChange = nil;
    
    for( NSManagedObject *eachObject in addedObjects ) {
        if( ![eachObject isKindOfClass:[TICDSSynchronizedManagedObject class]] ) {
            continue;
        }
        
        eachChange = [self createSyncChangeForChangeType:TICDSSyncChangeTypeToManyRelationshipChangedByAddingObject];
        
        TICDSLog(TICDSLogVerbosityManagedObjectOutput, @"[%@] %@", eachChange.objectSyncID, [self class]);

        [eachChange setRelatedObjectEntityName:[[aRelationship destinationEntity] name]];
        [eachChange setRelevantKey:[aRelationship name]];
        [eachChange setChangedRelationships:[eachObject valueForKey:TICDSSyncIDAttributeName]];
    }
    
    for( NSManagedObject *eachObject in removedObjects ) {
        if( ![eachObject isKindOfClass:[TICDSSynchronizedManagedObject class]] ) {
            continue;
        }
        
        eachChange = [self createSyncChangeForChangeType:TICDSSyncChangeTypeToManyRelationshipChangedByRemovingObject];
        
        TICDSLog(TICDSLogVerbosityManagedObjectOutput, @"[%@] %@", eachChange.objectSyncID, [self class]);

        [eachChange setRelatedObjectEntityName:[[aRelationship destinationEntity] name]];
        [eachChange setRelevantKey:[aRelationship name]];
        [eachChange setChangedRelationships:[eachObject valueForKey:TICDSSyncIDAttributeName]];
    }
}

#pragma mark -
#pragma mark Attributes
- (id)transformedValueOfAttribute:(NSString *)key
{
    NSAttributeDescription *attribute = [self.entity.attributesByName valueForKey:key];
    NSString *transformerName = [attribute valueTransformerName];
    NSValueTransformer *valueTransformer = ( transformerName ? [NSValueTransformer valueTransformerForName:transformerName] : nil );
    id transformedValue = [self valueForKey:key];
    if ( valueTransformer ) transformedValue = [valueTransformer transformedValue:transformedValue];
    return transformedValue;
}

- (id)reverseTransformedValueOfAttribute:(NSString *)key withValue:(id)value
{
    NSAttributeDescription *attribute = [self.entity.attributesByName valueForKey:key];
    NSString *transformerName = [attribute valueTransformerName];
    NSValueTransformer *valueTransformer = ( transformerName ? [NSValueTransformer valueTransformerForName:transformerName] : nil );
    if ( valueTransformer ) value = [valueTransformer reverseTransformedValue:value];
    return value;
}

- (NSDictionary *)dictionaryOfAllAttributes
{
    NSDictionary *objectAttributeNames = [[self entity] attributesByName];
    
    NSMutableDictionary *attributeValues = [NSMutableDictionary dictionaryWithCapacity:[objectAttributeNames count]];
    for( NSString *eachAttributeName in [objectAttributeNames allKeys] ) {
        NSAttributeDescription *attribute = [objectAttributeNames valueForKey:eachAttributeName];
        if ( [attribute isTransient] ) continue;
        id value = [self transformedValueOfAttribute:eachAttributeName];
        [attributeValues setValue:value forKey:eachAttributeName];
    }
    
    return attributeValues;
}

#pragma mark -
#pragma mark Save Notification
- (void)willSave
{
    [super willSave];
    
    if ( self.excludeFromSync ) return;
    
    // if not in a synchronized MOC, or we don't have a doc sync manager, exit now
    if( ![[self managedObjectContext] isKindOfClass:[TICDSSynchronizedManagedObjectContext class]] || ![(TICDSSynchronizedManagedObjectContext *)[self managedObjectContext] documentSyncManager] ) {
        
        if(![[self managedObjectContext] isKindOfClass:[TICDSSynchronizedManagedObjectContext class]]) {
            TICDSLog(TICDSLogVerbosityManagedObjectOutput, @"Skipping sync change creation for %@ because our managedObjectContext is not a TICDSSynchronizedManagedObjectContext.", [self class]);
        }
        
        if([[self managedObjectContext] isKindOfClass:[TICDSSynchronizedManagedObjectContext class]] && ![(TICDSSynchronizedManagedObjectContext *)[self managedObjectContext] documentSyncManager]) {
            TICDSLog(TICDSLogVerbosityManagedObjectOutput, @"Skipping sync change creation for %@ because our managedObjectContext has no documentSyncManager.", [self class]);
        }
        
        return;
    }
    
    if( [self isInserted] ) {
        [self createSyncChangeForInsertion];
    }
    
    if( [self isUpdated] ) {
        [self createSyncChangesForChangedProperties];
    }
    
    if( [self isDeleted] ) {
        [self createSyncChangeForDeletion];
    }
}

#pragma mark -
#pragma mark Managed Object Lifecycle
- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    [self setValue:[TICDSUtilities uuidString] forKey:TICDSSyncIDAttributeName];
}

#pragma mark -
#pragma mark Properties
- (NSManagedObjectContext *)syncChangesMOC
{
    if( ![[self managedObjectContext] isKindOfClass:[TICDSSynchronizedManagedObjectContext class]] ) return nil;
    
    return [[(TICDSSynchronizedManagedObjectContext *)[self managedObjectContext] documentSyncManager] syncChangesMocForDocumentMoc:(TICDSSynchronizedManagedObjectContext *)[self managedObjectContext]];
}

@end
