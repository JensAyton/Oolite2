/*

OOCharacter.h

Represents an NPC person (as opposed to an NPC ship).

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

#import "OOTypes.h"
#import "OOJSPropID.h"

#ifdef OO_BRAIN_AI
@class OOBrain;
#endif
@class OOJSScript;


@interface OOCharacter : NSObject
{
	NSString			*name;
	NSString			*shortDescription;
	NSString			*longDescription;
	Random_Seed			originSystemSeed;
	Random_Seed			genSeed;
	int					legalStatus;
	OOCreditsQuantity	insuranceCredits;
	
#ifdef OO_BRAIN_AI
	OOBrain				*brain;				// brain of character
#endif
	
	OOJSScript			*_script;
}

- (id) initWithGenSeed:(Random_Seed)g_seed andOriginalSystemSeed:(Random_Seed)s_seed;
- (id) initWithRole:(NSString *)role andOriginalSystemSeed:(Random_Seed)s_seed;

+ (OOCharacter *) characterWithRole:(NSString *)c_role andOriginalSystem:(Random_Seed)o_seed;
+ (OOCharacter *) randomCharacterWithRole:(NSString *)c_role andOriginalSystem:(Random_Seed)o_seed;
+ (OOCharacter *) characterWithDictionary:(NSDictionary *)c_dict;

- (NSString*) planetOfOrigin;
- (NSString*) species;

- (void) basicSetUp;
- (BOOL) castInRole:(NSString *)role;

- (NSString *) name;
- (void) setName:(NSString *)value;

- (NSString *) shortDescription;
- (void) setShortDescription:(NSString *)value;

- (NSString *) longDescription;
- (void) setLongDescription:(NSString *)value;

- (Random_Seed) originSystemSeed;
- (void) setOriginSystemSeed:(Random_Seed)value;

- (Random_Seed) genSeed;
- (void) setGenSeed:(Random_Seed)value;

- (int) legalStatus;
- (void) setLegalStatus:(int)value;

- (OOCreditsQuantity) insuranceCredits;
- (void) setInsuranceCredits:(OOCreditsQuantity)value;

- (OOJSScript *)script;
- (void) setCharacterScript:(NSString *)script_name;
- (void) doScriptEvent:(jsid)message;

#ifdef OO_BRAIN_AI
- (OOBrain *) brain;
- (void) setBrain:(OOBrain *)aBrain;
#endif

@end
