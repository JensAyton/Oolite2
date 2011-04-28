/*

NSStringOOExtensions.m

Oolite
Copyright © 2004-2010 Giles C Williams and contributors

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

#import "NSStringOOExtensions.h"
#import "OOCocoa.h"


@implementation NSString (OOExtensions)

+ (id) oo_stringWithContentsOfUnicodeFile:(NSString *)path
{
	id				result = nil;
	BOOL			OK = YES;
	NSData			*data = nil;
	const uint8_t	*bytes = NULL;
	size_t			length = 0;
	const uint8_t	*effectiveBytes = NULL;
	size_t			effectiveLength = 0;
	
	data = [[NSData alloc] initWithContentsOfFile:path];
	if (data == nil) OK = NO;
	
	if (OK)
	{
		length = [data length];
		bytes = [data bytes];
	}
	
	if (OK && 2 <= length && (length % sizeof(unichar)) == 0)
	{
		// Could be UTF-16
		unichar firstChar = (bytes[0] << 8) | bytes[1];	// Endianism doesn't matter, because we test both orders of BOM.
		if (firstChar == 0xFFFE || firstChar == 0xFEFF)
		{
			// Consider it to be UTF-16.
			result = [NSString stringWithCharacters:(unichar *)(bytes + sizeof(unichar)) length:(length / sizeof(unichar)) - 1];
			if (result == nil) OK = NO;
		}
	}
	
	if (OK && result == nil)
	{
		// Not UTF-16. Try UTF-8.
		if (3 <= length && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF)
		{
			// File starts with UTF-8 BOM; skip it.
			effectiveBytes = bytes + 3;
			effectiveLength = length + 3;
		}
		else
		{
			effectiveBytes = bytes;
			effectiveLength = length;
		}
		
		// Attempt to interpret as UTF-8
		result = [[[NSString alloc] initWithBytes:effectiveBytes length:effectiveLength encoding:NSUTF8StringEncoding] autorelease];
	}
	
	if (OK && result == nil)
	{
		// Not UTF-16 or UTF-8. Use ISO-Latin-1 (which should work for any byte sequence).
		result = [[[NSString alloc] initWithBytes:effectiveBytes length:effectiveLength encoding:NSISOLatin1StringEncoding] autorelease];
	}
	
	[data release];
	return result;
}


+ (id) oo_stringWithUTF16String:(const unichar *)chars
{
	size_t			length;
	const unichar	*end;
	
	if (chars == NULL) return nil;
	
	// Find length of string.
	end = chars;
	while (*end++) {}
	length = end - chars - 1;
	
	return [NSString stringWithCharacters:chars length:length];
}


- (NSData *) oo_utf16DataWithBOM:(BOOL)includeByteOrderMark
{
	size_t			lengthInChars;
	size_t			lengthInBytes;
	unichar			*buffer = NULL;
	unichar			*characters = NULL;
	
	// Calculate sizes
	lengthInChars = [self length];
	lengthInBytes = lengthInChars * sizeof(unichar);
	if (includeByteOrderMark) lengthInBytes += sizeof(unichar);
	
	// Allocate buffer
	buffer = malloc(lengthInBytes);
	if (buffer == NULL) return nil;
	
	// write BOM (native-endian) if desired
	characters = buffer;
	if (includeByteOrderMark)
	{
		*characters++ = 0xFEFF;
	}
	
	// Get the contents
	[self getCharacters:characters];
	
	// NSData takes ownership of the buffer.
	return [NSData dataWithBytesNoCopy:buffer length:lengthInBytes freeWhenDone:YES];
}


- (uint32_t) oo_hash
{
	OOUInteger i, length = [self length];
	uint32_t hash = 5381;
	for (i = 0; i < length; i++)
	{
		hash = ((hash << 5) + hash) /* 33 * hash */ ^ [self characterAtIndex:i];
	}
	return hash;
}


- (NSString *) oo_escapedForJavaScriptLiteral
{
	NSMutableString			*result = nil;
	NSUInteger				i, length;
	unichar					c;
	NSAutoreleasePool		*pool = nil;
	
	length = [self length];
	result = [NSMutableString stringWithCapacity:[self length]];
	
	// Not hugely efficient.
	pool = [[NSAutoreleasePool alloc] init];
	for (i = 0; i != length; ++i)
	{
		c = [self characterAtIndex:i];
		switch (c)
		{
			case '\\':
				[result appendString:@"\\\\"];
				break;
				
			case '\b':
				[result appendString:@"\\b"];
				break;
				
			case '\f':
				[result appendString:@"\\f"];
				break;
				
			case '\n':
				[result appendString:@"\\n"];
				break;
				
			case '\r':
				[result appendString:@"\\r"];
				break;
				
			case '\t':
				[result appendString:@"\\t"];
				break;
				
#if 0

			IMPORTANT: these are deliberately excluded because they aren not
			permitted in JSON.
				
			case '\v':
				[result appendString:@"\\v"];
				break;
				
			case '\'':
				[result appendString:@"\\\'"];
				break;
#endif
				
			case '\"':
				[result appendString:@"\\\""];
				break;
				
			default:
				[result appendString:[NSString stringWithCharacters:&c length:1]];
		}
	}
	[pool release];
	return result;
}

@end


@implementation NSMutableString (OOExtensions)

- (void) oo_appendLine:(NSString *)line
{
	[self appendString:line ? [line stringByAppendingString:@"\n"] : (NSString *)@"\n"];
}


- (void) oo_appendFormatLine:(NSString *)fmt, ...
{
	va_list args;
	va_start(args, fmt);
	[self oo_appendFormatLine:fmt arguments:args];
	va_end(args);
}


- (void) oo_appendFormatLine:(NSString *)fmt arguments:(va_list)args
{
	NSString *formatted = [[NSString alloc] initWithFormat:fmt arguments:args];
	[self oo_appendLine:formatted];
	[formatted release];
}


- (void) oo_deleteCharacterAtIndex:(unsigned long)index
{
	[self deleteCharactersInRange:NSMakeRange(index, 1)];
}

@end


NSString *OOTabString(NSUInteger count)
{
	NSString * const staticTabs[] =
	{
		@"",
		@"\t",
		@"\t\t",
		@"\t\t\t",
		@"\t\t\t\t",
		@"\t\t\t\t\t",			// 5
		@"\t\t\t\t\t\t",
		@"\t\t\t\t\t\t\t",
		@"\t\t\t\t\t\t\t\t",
		@"\t\t\t\t\t\t\t\t\t",
		@"\t\t\t\t\t\t\t\t\t\t"	// 10
	};
	enum { kStaticTabCount = sizeof staticTabs / sizeof *staticTabs };
	
	if (count < kStaticTabCount)
	{
		return staticTabs[count];
	}
	else
	{
		return [staticTabs[kStaticTabCount - 1] stringByAppendingString:OOTabString(count - (kStaticTabCount - 1))];
	}
}
