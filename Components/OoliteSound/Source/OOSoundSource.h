/*

OOSoundSource.h

A sound source.
Each playing sound is associated with a sound source, either explicitly or by
creating one on the fly. Each sound source can play one sound at a time, and
has a number of attributes related to positional audio (which is currently
unimplemented).

 
Copyright (C) 2006-2011 Jens Ayton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

#import "OOSoundSource.h"

@class OOSound, OOSoundChannel, OOSoundReferencePoint;


@interface OOSoundSource: NSObject
{
	OOSound						*_sound;
	BOOL						_loop;
	uint8_t						_repeatCount,
								_remainingCount;
}

// These options should be set before playing. Effect of setting them while playing is undefined.
- (OOSound *) sound;
- (void )setSound:(OOSound *)inSound;
- (BOOL) loop;
- (void) setLoop:(BOOL)inLoop;
- (uint8_t) repeatCount;
- (void) setRepeatCount:(uint8_t)inCount;

- (BOOL) isPlaying;
- (void) play;
- (void) playOrRepeat;
- (void) stop;

// Conveniences:
- (void) playSound:(OOSound *)inSound;
- (void) playSound:(OOSound *)inSound repeatCount:(uint8_t)inCount;
- (void) playOrRepeatSound:(OOSound *)inSound;

// Positional audio attributes are ignored in this implementation
- (void) setPositional:(BOOL)inPositional;
- (void) setPosition:(Vector)inPosition;
- (void) setVelocity:(Vector)inVelocity;
- (void) setOrientation:(Vector)inOrientation;
- (void) setConeAngle:(float)inAngle;
- (void) setGainInsideCone:(float)inInside outsideCone:(float)inOutside;
- (void) positionRelativeTo:(OOSoundReferencePoint *)inPoint;

@end
