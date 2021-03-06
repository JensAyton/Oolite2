/*

OOECMBlastEntity.h

Invisible entity which radiates ECM blast energy.


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

#import "OOEntity.h"

@class OOShipEntity;


@interface OOECMBlastEntity: OOEntity
{
@private
	OOTimeDelta			_nextBlast;
	uint_fast8_t		_blastsRemaining;
}


- (id) initFromShip:(OOShipEntity *)ship;

@end


@interface OOEntity (OOECMBlastEntity)

- (BOOL) isECMBlast;

@end
