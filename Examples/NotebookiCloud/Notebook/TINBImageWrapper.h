//
//  TINBImageWrapper.h
//  Notebook
//
//  Created by Drew McCormack on 13/07/12.
//  Copyright (c) 2012 Tim Isted. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "TICoreDataSync.h"

@class TINBNote;

@interface TINBImageWrapper : TICDSSynchronizedManagedObject

@property (nonatomic, readwrite, retain) NSImage *image;
@property (nonatomic, readwrite, retain) TINBNote *note;

@end
