/*

NSThreadOOExtensions.m

 
Copyright © 2007 Jens Ayton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

#import "NSThreadOOExtensions.h"
#include <pthread.h>


#if OOLITE_MAC_OS_X
#define OO_HAVE_PTHREAD_SETNAME_NP 1
#endif


#if !OO_HAVE_PTHREAD_SETNAME_NP
#define pthread_setname_np(name) do {} while (0)
#endif


@interface NSThread (LeopardAdditions)
- (void) setName:(NSString *)name;
@end

@interface NSLock (LeopardAdditions)
- (void) setName:(NSString *)name;
@end

@interface NSRecursiveLock (LeopardAdditions)
- (void) setName:(NSString *)name;
@end

@interface NSConditionLock (LeopardAdditions)
- (void) setName:(NSString *)name;
@end


@implementation NSThread (OOExtensions)

+ (void) ooSetCurrentThreadName:(NSString *)name
{
	// We may be called with no pool in place.
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSThread *thread = [NSThread currentThread];
	if ([thread respondsToSelector:@selector(setName:)])
	{
		[thread setName:name];
	}
	/*	Under Mac OS X 10.6, the name set by pthread_setname_np() is used in
		crash reports, but, annoyingly, -[NSThread setName:] does not call it.
	*/
	pthread_setname_np([name UTF8String]);
	
	[pool release];
}

@end


@implementation NSLock (OOExtensions)

- (void) ooSetName:(NSString *)name
{
	if ([self respondsToSelector:@selector(setName:)])
	{
		[self setName:name];
	}
}

@end


@implementation NSRecursiveLock (OOExtensions)

- (void) ooSetName:(NSString *)name
{
	if ([self respondsToSelector:@selector(setName:)])
	{
		[self setName:name];
	}
}

@end


@implementation NSConditionLock (OOExtensions)

- (void) ooSetName:(NSString *)name
{
	if ([self respondsToSelector:@selector(setName:)])
	{
		[self setName:name];
	}
}

@end
