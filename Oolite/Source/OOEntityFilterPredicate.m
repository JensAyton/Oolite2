/*

OOEntityFilterPredicate.h

Filters used to select entities in various contexts.


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

#import "OOEntityFilterPredicate.h"
#import "Entity.h"
#import "ShipEntity.h"
#import "OOPlanetEntity.h"
#import "OORoleSet.h"


BOOL YESPredicate(Entity *entity, void *parameter)
{
	return YES;
}


BOOL NOPredicate(Entity *entity, void *parameter)
{
	return NO;
}


BOOL HasScanClassPredicate(Entity *entity, void *parameter)
{
	return [(id)parameter intValue] == [entity scanClass];
}


BOOL IsPlanetPredicate(Entity *entity, void *parameter)
{
	if (![entity isPlanet])  return NO;
	OOStellarBodyType type = [(OOPlanetEntity *)entity planetType];
	return (type == STELLAR_TYPE_NORMAL_PLANET || type == STELLAR_TYPE_MOON);
}


BOOL IsHostileAgainstTargetPredicate(Entity *ship, void *parameter)
{
	ShipEntity *self = (ShipEntity *)ship, *target = parameter;
	
	return ((target == [self primaryTarget] && [self hasHostileTarget]) ||
			([self isThargoid] && ![target isThargoid]));
}
