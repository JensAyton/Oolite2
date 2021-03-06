/*

AI.h

Core NPC behaviour/artificial intelligence class.

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

#define AI_THINK_INTERVAL					0.125


@class OOShipEntity;
#ifdef OO_BRAIN_AI
@class OOInstinct;
#endif


@interface AI : OOWeakRefObject
{
	id					_owner;						// OOWeakReference to the OOShipEntity this is the AI for
	NSString			*ownerDesc;					// describes the object this is the AI for
	
	NSDictionary		*stateMachine;
	NSString			*stateMachineName;
	NSString			*currentState;
	NSMutableSet		*pendingMessages;
	
	NSMutableArray		*aiStack;
	
#ifdef OO_BRAIN_AI
	OOInstinct			*rulingInstinct;
#endif
	
	OOTimeAbsolute		nextThinkTime;
	OOTimeDelta			thinkTimeInterval;
	
}

+ (AI *) currentlyRunningAI;
+ (NSString *) currentlyRunningAIDescription;

- (NSString *) name;
- (NSString *) state;

- (void) setStateMachine:(NSString *)smName;
- (void) setState:(NSString *)stateName;

- (void) setStateMachine:(NSString *)smName afterDelay:(NSTimeInterval)delay;
- (void) setState:(NSString *)stateName afterDelay:(NSTimeInterval)delay;

- (id) initWithStateMachine:(NSString *) smName andState:(NSString *) stateName;

#ifdef OO_BRAIN_AI
- (OOInstinct *) rulingInstinct;
- (void) setRulingInstinct:(OOInstinct*) instinct;
#endif

- (OOShipEntity *)owner;
- (void) setOwner:(OOShipEntity *)ship;

- (void) preserveCurrentStateMachine;

- (void) restorePreviousStateMachine;

- (BOOL) hasSuspendedStateMachines;
- (void) exitStateMachineWithMessage:(NSString *)message;

- (unsigned) stackDepth;

// Immediately handle a message. This is the core dispatcher. DebugContext is a textual hint for diagnostics.
- (void) reactToMessage:(NSString *) message context:(NSString *)debugContext;

- (void) takeAction:(NSString *) action;

- (void) think;

- (void) message:(NSString *) ms;
- (void) dropMessage:(NSString *) ms;
- (NSSet *) pendingMessages;
- (void) debugDumpPendingMessages;

- (void) setNextThinkTime:(OOTimeAbsolute) ntt;
- (OOTimeAbsolute) nextThinkTime;

- (void) setThinkTimeInterval:(OOTimeDelta) tti;
- (OOTimeDelta) thinkTimeInterval;

- (void) clearStack;

- (void) clearAllData;

- (void)dumpState;

@end
