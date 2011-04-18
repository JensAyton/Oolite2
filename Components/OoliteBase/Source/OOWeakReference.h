/*

OOWeakReference.h

Weak reference class for Cocoa/GNUstep/OpenStep.

A weak reference allows code to maintain a reference to an object while
allowing the object to reach a retain count of zero and deallocate itself.
To function, the referenced object must implement the OOWeakReferenceSupport
protocol.

Client use is extremely simple: to get a weak reference to the object, call
-weakRetain and use the returned proxy instead of the actual object. When
finished, release the proxy. Messages sent to the proxy will be forwarded as
long as the underlying object exists; beyond that, they will act exactly like
messages to nil. (IMPORTANT: this means messages returning floating-point or
struct values have undefined return values, so use -weakRefObjectStillExists
or -weakRefUnderlyingObject in such cases.) Example:

@interface ThingWatcher: NSObject
{
	Thing			*thing;
}
@end

@implementation ThingWatcher
- (void)setThing:(Thing *)aThing
{
	[thing release];
	thing = [aThing weakRetain];
}

- (void)frobThing
{
	[thing frob];
}

- (void)dealloc
{
	[thing release];
	[super dealloc];
}
@end


Note that the only reference to OOWeakReference being involved is the call to
weakRetain instead of retain. However, the following would not work:
	thing = aThing;
	[thing weakRetain];

Additionally, it is not possible to access instance variables directly -- but
then, that's a filthy habit.

OOWeakReferenceSupport implementation is also simple:

@interface Thing: NSObject <OOWeakReferenceSupport>
{
	OO_WEAK OOWeakReference	*_weakSelf;
}
@end

@implementation Thing
- (id)weakRetain
{
	if (weakSelf == nil)  _weakSelf = [OOWeakReference weakRefWithObject:self];
	return [_weakSelf retain];
}

- (void)weakRefDied:(OOWeakReference *)weakRef
{
	if (weakRef == _weakSelf)  _weakSelf = nil;
}

- (void)dealloc
{
	[_weakSelf weakRefDrop];	// Very important!
	[super dealloc];
}

- (void)frob
{
	NSBeep();
}
@end


Copyright © 2007-2011 Jens Ayton
This code is hereby placed in the public domain.

*/

#import <Foundation/Foundation.h>
#import "OOFunctionAttributes.h"
#import "OOGarbageCollectionSupport.h"

@class OOWeakReference;


@protocol OOWeakReferenceSupport <NSObject>

- (id)weakRetain OO_RETURNS_RETAINED;		// Returns a retained OOWeakReference, which should be released when finished with.
- (void)weakRefDied:(OOWeakReference *)weakRef;

@end


@interface OOWeakReference: NSProxy
{

	OO_WEAK id<OOWeakReferenceSupport>	_object;
}

- (BOOL)weakRefObjectStillExists;
- (id)weakRefUnderlyingObject;

- (id)weakRetain OO_RETURNS_RETAINED;	// Returns [self retain] for weakrefs.

// For referred object only:
+ (id)weakRefWithObject:(id<OOWeakReferenceSupport>)object;
- (void)weakRefDrop;

@end


@interface NSObject (OOWeakReference)

- (BOOL)weakRefObjectStillExists;	// Always YES for non-weakrefs. ObjC semantics causes it to return NO for nil, so it acts as an existence check.
- (id)weakRefUnderlyingObject;		// Always self for non-weakrefs (and of course nil for nil).

@end


/*	OOWeakRefObject
	Simple object implementing OOWeakReferenceSupport, to subclass. This
	provides a full implementation for simplicity, but keep in mind that the
	protocol can be implemented by any class.
*/
@interface OOWeakRefObject: NSObject <OOWeakReferenceSupport>
{
	OOWeakReference		*weakSelf;
}
@end
