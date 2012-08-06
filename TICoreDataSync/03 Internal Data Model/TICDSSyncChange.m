//
//  TICDSyncChange.m
//  ShoppingListMac
//
//  Created by Tim Isted on 23/04/2011.
//  Copyright (c) 2011 Tim Isted. All rights reserved.
//

#import "TICoreDataSync.h"

@implementation TICDSSyncChange

static NSString *bigDataDirectory = nil;

+ (void)initialize
{
    if ( bigDataDirectory == nil ) {
        bigDataDirectory = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"TICDSSyncChangeData"] retain];
        if ( [[NSFileManager defaultManager] fileExistsAtPath:bigDataDirectory] ) {
            [[NSFileManager defaultManager] removeItemAtPath:bigDataDirectory error:NULL];
        }
        [[NSFileManager defaultManager] createDirectoryAtPath:bigDataDirectory withIntermediateDirectories:NO attributes:nil error:NULL];
    }
}

#pragma mark -
#pragma mark Helper Methods
+ (id)syncChangeOfType:(TICDSSyncChangeType)aType inManagedObjectContext:(NSManagedObjectContext *)aMoc
{
    TICDSSyncChange *syncChange = [self ti_objectInManagedObjectContext:aMoc];
    
    [syncChange setLocalTimeStamp:[NSDate date]];
    [syncChange setChangeType:[NSNumber numberWithInt:aType]];
    
    return syncChange;
}

#pragma mark -
#pragma mark Inspection
- (NSString *)shortDescription
{
    return [NSString stringWithFormat:@"%@ %@", TICDSSyncChangeTypeNames[ [[self changeType] unsignedIntValue] ], [self objectEntityName]];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"\n%@\nCHANGED ATTRIBUTES\n%@\nCHANGED RELATIONSHIPS\n%@", [super description], [self changedAttributes], [self changedRelationships]];
}

#pragma mark -
#pragma mark TIManagedObjectExtensions
+ (NSString *)ti_entityName
{
    return NSStringFromClass([self class]);
}

#pragma mark -
#pragma mark Low Memory

- (NSData *)mappedDataFromData:(NSData *)data withFilename:(NSString *)filename
{
    NSString *path = [bigDataDirectory stringByAppendingPathComponent:filename];
    [data writeToFile:path atomically:NO];
    id newData = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedAlways error:NULL];
    return newData ? : data;
}

- (id)lowMemoryChangedAttributesFromAttributes:(id)changedAttributes
{
    id result = changedAttributes;
    
    if ( [changedAttributes isKindOfClass:[NSData class]] && [changedAttributes length] > 10000 ) {
        NSString *uniqueString = [[NSProcessInfo processInfo] globallyUniqueString];
        result = [self mappedDataFromData:changedAttributes withFilename:uniqueString];
    }
    else if ( [changedAttributes isKindOfClass:[NSDictionary class]] ) {
        NSMutableDictionary *newResult = [NSMutableDictionary dictionaryWithDictionary:changedAttributes];
        for ( id key in changedAttributes ) {
            id value = [changedAttributes valueForKey:key];
            if ( [value isKindOfClass:[NSData class]] && [value length] > 10000 ) {
                NSString *uniqueString = [[NSProcessInfo processInfo] globallyUniqueString];
                id newValue = [self mappedDataFromData:value withFilename:uniqueString];
                [newResult setValue:newValue forKey:key];
            }
        }
        result = newResult;
    }
                                        
    return result;
}

- (void)setChangedAttributes:(id)changedAttributes
{
    [self willChangeValueForKey:@"changedAttributes"];
    id lowMemAttributes = [self lowMemoryChangedAttributesFromAttributes:changedAttributes];
    [self setPrimitiveValue:lowMemAttributes forKey:@"changedAttributes"];
    [self didChangeValueForKey:@"changedAttributes"];
}

- (id)changedAttributes
{
    [self willAccessValueForKey:@"changedAttributes"];
    id result = [self primitiveValueForKey:@"changedAttributes"];
    result = [self lowMemoryChangedAttributesFromAttributes:result];
    [self didAccessValueForKey:@"changedAttributes"];
    return result;
}

@dynamic changeType;
@synthesize relevantManagedObject = _relevantManagedObject;
@dynamic objectEntityName;
@dynamic objectSyncID;
@dynamic changedAttributes;
@dynamic changedRelationships;
@dynamic relevantKey;
@dynamic localTimeStamp;
@dynamic relatedObjectEntityName;

@end
