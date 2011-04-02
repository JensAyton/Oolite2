/*

OOJSClock.m


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

#import "OOJSClock.h"
#import "OOJavaScriptEngine.h"
#import "Universe.h"
#import "OOJSPlayer.h"
#import "PlayerEntity.h"
#import "PlayerEntityScriptMethods.h"
#import "OOStringParsing.h"


static JSBool ClockGetProperty(JSContext *context, JSObject *this, jsid propID, jsval *value);

// Methods
static JSBool JSClockToString(JSContext *context, uintN argc, jsval *vp);
static JSBool ClockClockStringForTime(JSContext *context, uintN argc, jsval *vp);
static JSBool ClockAddSeconds(JSContext *context, uintN argc, jsval *vp);


static JSClass sClockClass =
{
	"Clock",
	JSCLASS_HAS_PRIVATE,
	
	JS_PropertyStub,		// addProperty
	JS_PropertyStub,		// delProperty
	ClockGetProperty,		// getProperty
	JS_StrictPropertyStub,	// setProperty
	JS_EnumerateStub,		// enumerate
	JS_ResolveStub,			// resolve
	JS_ConvertStub,			// convert
	JS_FinalizeStub,		// finalize
	JSCLASS_NO_OPTIONAL_MEMBERS
};


enum
{
	// Property IDs
	kClock_absoluteSeconds,		// game real time clock, double, read-only
	kClock_seconds,				// game clock time, double, read-only
	kClock_minutes,				// game clock time minutes (rounded down), integer double, read-only
	kClock_hours,				// game clock time hours (rounded down), integer double, read-only
	kClock_days,				// game clock time days (rounded down), int, read-only
	kClock_secondsComponent,	// second component of game clock time, double, read-only
	kClock_minutesComponent,	// minute component of game clock time (rounded down), int, read-only
	kClock_hoursComponent,		// hour component of game clock time (rounded down), int, read-only
	kClock_daysComponent,		// day component of game clock time (rounded down), int, read-only
	kClock_clockString,			// game clock time as display string, string, read-only
	kClock_isAdjusting			// clock is adjusting, boolean, read-only
};


static JSPropertySpec sClockProperties[] =
{
	// JS name					ID							flags
	{ "absoluteSeconds",		kClock_absoluteSeconds,		OOJS_PROP_READONLY_CB },
	{ "seconds",				kClock_seconds,				OOJS_PROP_READONLY_CB },
	{ "minutes",				kClock_minutes,				OOJS_PROP_READONLY_CB },
	{ "hours",					kClock_hours,				OOJS_PROP_READONLY_CB },
	{ "days",					kClock_days,				OOJS_PROP_READONLY_CB },
	{ "secondsComponent",		kClock_secondsComponent,	OOJS_PROP_READONLY_CB },
	{ "minutesComponent",		kClock_minutesComponent,	OOJS_PROP_READONLY_CB },
	{ "hoursComponent",			kClock_hoursComponent,		OOJS_PROP_READONLY_CB },
	{ "daysComponent",			kClock_daysComponent,		OOJS_PROP_READONLY_CB },
	{ "clockString",			kClock_clockString,			OOJS_PROP_READONLY_CB },
	{ "isAdjusting",			kClock_isAdjusting,			OOJS_PROP_READONLY_CB },
	{ 0 }
};


static JSFunctionSpec sClockMethods[] =
{
	// JS name						Function						min args
	{ "toString",				JSClockToString,			0 },
	{ "clockStringForTime",		ClockClockStringForTime,	1 },
	{ "addSeconds",				ClockAddSeconds,			1 },
	{ 0 }
};


void InitOOJSClock(JSContext *context, JSObject *global)
{
	JSObject *clockPrototype = JS_InitClass(context, global, NULL, &sClockClass, OOJSUnconstructableConstruct, 0, sClockProperties, sClockMethods, NULL, NULL);
	JS_DefineObject(context, global, "clock", &sClockClass, clockPrototype, OOJS_PROP_READONLY);
}


static JSBool ClockGetProperty(JSContext *context, JSObject *this, jsid propID, jsval *value)
{
	if (!JSID_IS_INT(propID))  return YES;
	
	OOJS_NATIVE_ENTER(context)
	
	double						clockTime;
	
	clockTime = [PLAYER clockTime];
	
	switch (JSID_TO_INT(propID))
	{
		case kClock_absoluteSeconds:
			return JS_NewNumberValue(context, [UNIVERSE gameTime], value);
			
		case kClock_seconds:
			return JS_NewNumberValue(context, clockTime, value);
			
		case kClock_minutes:
			return JS_NewNumberValue(context, floor(clockTime / kOOSecondsPerMinute), value);
			
		case kClock_hours:
			return JS_NewNumberValue(context, floor(clockTime / kOOSecondsPerHour), value);
			return YES;
			
		case kClock_secondsComponent:
			*value = INT_TO_JSVAL(fmod(clockTime, kOOSecondsPerMinute));
			return YES;
			
		case kClock_minutesComponent:
			*value = INT_TO_JSVAL(fmod(floor(clockTime / kOOSecondsPerMinute), kOOMinutesPerHour));
			return YES;
			
		case kClock_hoursComponent:
			*value = INT_TO_JSVAL(fmod(floor(clockTime / kOOSecondsPerHour), kOOHoursPerDay));
			return YES;
			
		case kClock_days:
		case kClock_daysComponent:
			*value = INT_TO_JSVAL(floor(clockTime / kOOSecondsPerDay));
			return YES;
			
		case kClock_clockString:
			*value = OOJSValueFromNativeObject(context, [PLAYER dial_clock]);
			return YES;
			
		case kClock_isAdjusting:
			*value = OOJSValueFromBOOL([PLAYER isClockAdjusting]);
			return YES;
			
		default:
			OOJSReportBadPropertySelector(context, this, propID, sClockProperties);
			return NO;
	}
	
	OOJS_NATIVE_EXIT
}


// *** Methods ***

// toString() : String
static JSBool JSClockToString(JSContext *context, uintN argc, jsval *vp)
{
	OOJS_NATIVE_ENTER(context)
	
	OOJS_RETURN_OBJECT([PLAYER dial_clock]);
	
	OOJS_NATIVE_EXIT
}


// clockStringForTime(time : Number) : String
static JSBool ClockClockStringForTime(JSContext *context, uintN argc, jsval *vp)
{
	OOJS_NATIVE_ENTER(context)
	
	double						time;
	
	if (EXPECT_NOT(argc < 1 || !JS_ValueToNumber(context, OOJS_ARGV[0], &time)))
	{
		jsval arg = JSVAL_VOID;
		if (argc > 0)  arg = OOJS_ARGV[0];
		OOJSReportBadArguments(context, @"Clock", @"clockStringForTime", 1, &arg, nil, @"number");
		return NO;
	}
	
	OOJS_RETURN_OBJECT(ClockToString(time, NO));
	
	OOJS_NATIVE_EXIT
}


// addSeconds(seconds : Number) : String
static JSBool ClockAddSeconds(JSContext *context, uintN argc, jsval *vp)
{
	OOJS_NATIVE_ENTER(context)
	
	double						time;
	const double				kMaxTime = OODAYS(30.0);
	
	if (EXPECT_NOT(argc < 1 || !JS_ValueToNumber(context, OOJS_ARGV[0], &time)))
	{
		jsval arg = JSVAL_VOID;
		if (argc > 0)  arg = OOJS_ARGV[0];
		OOJSReportBadArguments(context, @"Clock", @"addSeconds", 1, &arg, nil, @"number");
		return NO;
	}
	
	if (time > kMaxTime || time < 1.0 || !isfinite(time))
	{
		OOJS_RETURN_BOOL(NO);
	}
	
	[PLAYER advanceClockBy:time];
	
	OOJS_RETURN_BOOL(YES);
	
	OOJS_NATIVE_EXIT
}
