/*
OOShipGroup.h

A weak-referencing, mutable set of ships. Not thread safe.


Oolite
Copyright (C) 2004-2011 Giles C Williams and contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

*/

#import <OoliteBase/OoliteBase.h>

@class OOShipEntity;


@interface OOShipGroup: OOWeakRefObject
#if OOLITE_FAST_ENUMERATION
<NSFastEnumeration>
#endif
{
@private
	NSUInteger				_count, _capacity;
	unsigned long			_updateCount;
	OOWeakReference			**_members;
	OOWeakReference			*_leader;
	NSString				*_name;
	
	struct JSObject			*_jsSelf;
}

- (id) init;
- (id) initWithName:(NSString *)name;
+ (id) groupWithName:(NSString *)name;
+ (id) groupWithName:(NSString *)name leader:(OOShipEntity *)leader;

- (NSString *) name;
- (void) setName:(NSString *)name;

- (OOShipEntity *) leader;
- (void) setLeader:(OOShipEntity *)leader;

- (NSEnumerator *) objectEnumerator;
- (NSEnumerator *) mutationSafeEnumerator;	// Enumerate over contents at time this is called, even if actual group is mutated.

- (NSSet *) members;
- (NSArray *) memberArray;	// arbitrary order
- (NSSet *) membersExcludingLeader;
- (NSArray *) memberArrayExcludingLeader;	// arbitrary order

- (BOOL) containsShip:(OOShipEntity *)ship;
- (void) addShip:(OOShipEntity *)ship;
- (void) removeShip:(OOShipEntity *)ship;

- (NSUInteger) count;		// NOTE: this is O(n).
- (BOOL) isEmpty;

@end
