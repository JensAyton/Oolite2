/*

GuiDisplayGen.m

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

#import "GuiDisplayGen.h"
#import "Universe.h"
#import "PlayerEntity.h"
#import "OOTextureSprite.h"
#import "ResourceManager.h"
#import "OOSound.h"
#import "OOStringParsing.h"
#import "HeadUpDisplay.h"
#import "OOTexture.h"
#import "OOJavaScriptEngine.h"
#import "OOColor.h"


OOINLINE BOOL RowInRange(OOGUIRow row, NSRange range)
{
	return ((int)range.location <= row && row < (int)(range.location + range.length));
}


@interface GuiDisplayGen (Internal)

- (void) drawGLDisplay:(GLfloat)x :(GLfloat)y :(GLfloat)z :(GLfloat) alpha;

- (void) drawCrossHairsWithSize:(GLfloat) size x:(GLfloat)x y:(GLfloat)y z:(GLfloat)z;
- (void) drawStarChart:(GLfloat)x :(GLfloat)y :(GLfloat)z :(GLfloat) alpha;
- (void) drawGalaxyChart:(GLfloat)x :(GLfloat)y :(GLfloat)z :(GLfloat) alpha;
- (void) drawEqptList: (NSArray *)eqptList z:(GLfloat)z;
- (void) drawAdvancedNavArrayAtX:(float)x y:(float)y z:(float)z alpha:(float)alpha usingRoute:(NSDictionary *) route optimizedBy:(OORouteType) optimizeBy;

@end


@implementation GuiDisplayGen

- (id) init
{
	self = [super init];
		
	size_in_pixels  = NSMakeSize(MAIN_GUI_PIXEL_WIDTH, MAIN_GUI_PIXEL_HEIGHT);
	n_columns		= GUI_DEFAULT_COLUMNS;
	n_rows			= GUI_DEFAULT_ROWS;
	pixel_row_center = size_in_pixels.width / 2;
	pixel_row_height = MAIN_GUI_ROW_HEIGHT;
	pixel_row_start	= MAIN_GUI_PIXEL_ROW_START;		// first position down the page...
	max_alpha = 1.0;

	pixel_text_size = NSMakeSize(0.9f * pixel_row_height, pixel_row_height);	// main gui has 18x20 characters
	
	pixel_title_size = NSMakeSize(pixel_row_height * 1.75f, pixel_row_height * 1.5f);
	
	int stops[6] = {0, 192, 256, 320, 384, 448};
	unsigned i;
	
	rowRange = NSMakeRange(0,n_rows);

	rowText =   [[NSMutableArray alloc] initWithCapacity:n_rows];   // alloc retains
	rowKey =	[[NSMutableArray alloc] initWithCapacity:n_rows];   // alloc retains
	rowColor =	[[NSMutableArray alloc] initWithCapacity:n_rows];   // alloc retains
	
	for (i = 0; i < n_rows; i++)
	{
		[rowText addObject:@"."];
		[rowKey addObject:[NSString stringWithFormat:@"%d",i]];
		[rowColor addObject:[OOColor yellowColor]];
		rowPosition[i].x = 0.0f;
		rowPosition[i].y = size_in_pixels.height - (pixel_row_start + i * pixel_row_height);
		rowAlignment[i] = GUI_ALIGN_LEFT;
	}
	
	for (i = 0; i < n_columns; i++)
	{
		tabStops[i] = stops[i];
	}
	
	title = @"";
	
	textColor = [[OOColor yellowColor] retain];
	
	drawPosition = make_vector(0.0f, 0.0f, 640.0f);

	return self;
}


- (id) initWithPixelSize:(NSSize)gui_size
				 columns:(int)gui_cols 
					rows:(int)gui_rows 
			   rowHeight:(int)gui_row_height
				rowStart:(int)gui_row_start
				   title:(NSString*)gui_title
{
	self = [super init];
		
	size_in_pixels  = gui_size;
	n_columns		= gui_cols;
	n_rows			= gui_rows;
	pixel_row_center = size_in_pixels.width / 2;
	pixel_row_height = gui_row_height;
	pixel_row_start	= gui_row_start;		// first position down the page...
	max_alpha = 1;

	pixel_text_size = NSMakeSize(pixel_row_height, pixel_row_height);
	
	pixel_title_size = NSMakeSize(pixel_row_height * 1.75f, pixel_row_height * 1.5f);
	
	unsigned i;
	
	rowRange = NSMakeRange(0,n_rows);

	rowText =   [[NSMutableArray alloc] initWithCapacity:n_rows];   // alloc retains
	rowKey =	[[NSMutableArray alloc] initWithCapacity:n_rows];   // alloc retains
	rowColor =	[[NSMutableArray alloc] initWithCapacity:n_rows];   // alloc retains
	
	for (i = 0; i < n_rows; i++)
	{
		[rowText addObject:@""];
		[rowKey addObject:@""];
		[rowColor addObject:[OOColor greenColor]];
		rowPosition[i].x = 0.0f;
		rowPosition[i].y = size_in_pixels.height - (pixel_row_start + i * pixel_row_height);
		rowAlignment[i] = GUI_ALIGN_LEFT;
	}
	
	title = [gui_title retain];
	
	textColor = [[OOColor yellowColor] retain];

	return self;
}


- (void) dealloc
{
	[backgroundSprite release];
	[foregroundSprite release];
	[backgroundColor release];
	[textColor release];
	[title release];
	[rowText release];
	[rowKey release];
	[rowColor release];
	
	[super dealloc];
}


- (void) resizeWithPixelSize:(NSSize)gui_size
					 columns:(int)gui_cols
						rows:(int)gui_rows
				   rowHeight:(int)gui_row_height
					rowStart:(int)gui_row_start
					   title:(NSString*) gui_title
{
	[self clear];
	//
	size_in_pixels  = gui_size;
	n_columns		= gui_cols;
	n_rows			= gui_rows;
	pixel_row_center = size_in_pixels.width / 2;
	pixel_row_height = gui_row_height;
	pixel_row_start	= gui_row_start;		// first position down the page...

	pixel_text_size = NSMakeSize(pixel_row_height, pixel_row_height);
	pixel_title_size = NSMakeSize(pixel_row_height * 1.75f, pixel_row_height * 1.5f);

	rowRange = NSMakeRange(0,n_rows);
	[self clear];
	//
	[self setTitle: gui_title];
}


- (void) resizeTo:(NSSize)gui_size
  characterHeight:(int)csize
			title:(NSString*)gui_title
{
	[self clear];
	//
	size_in_pixels  = gui_size;
	n_columns		= gui_size.width / csize;
	n_rows			= (int)gui_size.height / csize;

	[self setTitle: gui_title];
	
	pixel_row_center = gui_size.width / 2;
	pixel_row_height = csize;
	currentRow = n_rows - 1;		// first position down the page...

	if (title != nil)
		pixel_row_start = 2.75f * csize + 0.5f * (gui_size.height - n_rows * csize);
	else
		pixel_row_start = csize + 0.5f * (gui_size.height - n_rows * csize);

	[rowText removeAllObjects];
	[rowKey removeAllObjects];
	[rowColor removeAllObjects];

	unsigned i;
	for (i = 0; i < n_rows; i++)
	{
		[rowText addObject:@""];
		[rowKey addObject:@""];
		[rowColor addObject:[OOColor greenColor]];
		rowPosition[i].x = 0.0f;
		rowPosition[i].y = size_in_pixels.height - (pixel_row_start + i * pixel_row_height);
		rowAlignment[i] = GUI_ALIGN_LEFT;
	}

	pixel_text_size = NSMakeSize(csize, csize);
	pixel_title_size = NSMakeSize(csize * 1.75f, csize * 1.5f);
	
	OOLog(@"gui.reset", @"gui %@ reset to rows:%d columns:%d start:%d", self, n_rows, n_columns, pixel_row_start);

	rowRange = NSMakeRange(0,n_rows);
	[self clear];
}


- (NSSize)size
{
	return size_in_pixels;
}


- (unsigned)columns
{
	return n_columns;
}


- (unsigned)rows
{
	return n_rows;
}


- (unsigned)rowHeight
{
	return pixel_row_height;
}


- (int)rowStart
{
	return pixel_row_start;
}


- (NSString *)title
{
	return title;
}


- (void) setTitle:(NSString *)str
{
	if (str != title)
	{
		[title release];
		if ([str length] == 0)  str = nil;
		title = [str copy];
	}
}


- (void) setDrawPosition:(Vector) vector
{
	drawPosition = vector;
}


- (Vector) drawPosition
{
	return drawPosition;
}


- (void) fadeOutFromTime:(OOTimeAbsolute) now_time overDuration:(OOTimeDelta) duration
{
	if (fade_alpha <= 0.0f) 
	{
		return;
	}
	if (duration == 0.0)
		fade_sign = -1000.0f;
	else
		fade_sign = (float)(-fade_alpha / duration);
}


- (GLfloat) alpha
{
	return fade_alpha;
}


- (void) setAlpha:(GLfloat) an_alpha
{
	fade_alpha = an_alpha * max_alpha;
}


- (void) setMaxAlpha:(GLfloat) an_alpha
{
	max_alpha = an_alpha;
}


- (void) setBackgroundColor:(OOColor*) color
{
	[backgroundColor release];
	backgroundColor = [color retain];
}


- (void) setTextColor:(OOColor*) color
{
	[textColor release];
	if (color == nil)  color = [[OOColor yellowColor] retain];
	textColor = [color retain];
}


- (void) setCharacterSize:(NSSize) character_size
{
	pixel_text_size = character_size;
}


- (void)setShowAdvancedNavArray:(BOOL)inFlag
{
	showAdvancedNavArray = inFlag;
}


- (void) setColor:(OOColor *) color forRow:(OOGUIRow)row
{
	if (RowInRange(row, rowRange))
		[rowColor replaceObjectAtIndex:row withObject:color];
}


- (id) objectForRow:(OOGUIRow)row
{
	if (RowInRange(row, rowRange))
		return [rowText objectAtIndex:row];
	else
		return NULL;
}


- (NSString*) keyForRow:(OOGUIRow)row
{
	if (RowInRange(row, rowRange))
		return [rowKey objectAtIndex:row];
	else
		return NULL;
}


- (int) selectedRow
{
	if (RowInRange(selectedRow, selectableRange))
		return selectedRow;
	else
		return -1;
}


- (BOOL) setSelectedRow:(OOGUIRow)row
{
	if ((row == selectedRow)&&RowInRange(row, selectableRange))
		return YES;
	if (RowInRange(row, selectableRange))
	{
		if (![[rowKey objectAtIndex:row] isEqual:GUI_KEY_SKIP])
		{
			selectedRow = row;
			return YES;
		}
	}
	return NO;
}


- (BOOL) setNextRow:(int) direction
{
	int row = selectedRow + direction;
	while (RowInRange(row, selectableRange))
	{
		if (![[rowKey objectAtIndex:row] isEqual:GUI_KEY_SKIP])
		{
			selectedRow = row;
			return YES;
		}
		row += direction;
	}
	return NO;
}


- (BOOL) setFirstSelectableRow
{
	int row = selectableRange.location;
	while (RowInRange(row, selectableRange))
	{
		if (![[rowKey objectAtIndex:row] isEqual:GUI_KEY_SKIP])
		{
			selectedRow = row;
			return YES;
		}
		row++;
	}
	selectedRow = -1;
	return NO;
}


- (BOOL) setLastSelectableRow
{
	int row = selectableRange.location + selectableRange.length - 1;
	while (RowInRange(row, selectableRange))
	{
		if (![[rowKey objectAtIndex:row] isEqual:GUI_KEY_SKIP])
		{
			selectedRow = row;
			return YES;
		}
		row--;
	}
	selectedRow = -1;
	return NO;
}


- (void) setNoSelectedRow
{
	selectedRow = -1;
}


- (NSString *) selectedRowText
{
	if ([[rowText objectAtIndex:selectedRow] isKindOfClass:[NSString class]])
		return (NSString *)[rowText objectAtIndex:selectedRow];
	if ([[rowText objectAtIndex:selectedRow] isKindOfClass:[NSArray class]])
		return (NSString *)[[rowText objectAtIndex:selectedRow] objectAtIndex:0];
	return NULL;
}


- (NSString *) selectedRowKey
{
	if ((selectedRow < 0)||((unsigned)selectedRow > [rowKey count]))
		return nil;
	else
		return (NSString *)[rowKey objectAtIndex:selectedRow];
}


- (void) setShowTextCursor:(BOOL) yesno
{
	showTextCursor = yesno;
}


- (void) setCurrentRow:(OOGUIRow) value
{
	if ((value < 0)||((unsigned)value >= n_rows))
	{
		showTextCursor = NO;
		currentRow = -1;
	}
	else
	{
		currentRow = value;
	}
}


- (NSRange) selectableRange
{
	return selectableRange;
}


- (void) setSelectableRange:(NSRange) range
{
	selectableRange = range;
}


- (void) setTabStops:(OOGUITabSettings)stops
{
	if (stops != NULL)  memmove(tabStops, stops, sizeof tabStops);
}


- (void) clear
{
	[self clearAndKeepBackground:NO];
}


- (void) clearAndKeepBackground:(BOOL)keepBackground
{
	unsigned i;
	[self setTitle: nil];
	for (i = 0; i < n_rows; i++)
	{
		[self setText:@"" forRow:i align:GUI_ALIGN_LEFT];
		[self setColor:textColor forRow:i];
		//
		[self setKey:GUI_KEY_SKIP forRow:i];
		//
		rowFadeTime[i] = 0.0f;
	}
	[self setShowTextCursor:NO];
	[self setSelectableRange:NSMakeRange(0,0)];
	if (!keepBackground) [self clearBackground];
}


- (void) setKey:(NSString *)str forRow:(OOGUIRow)row
{
	if (RowInRange(row, rowRange))
		[rowKey replaceObjectAtIndex:row withObject:str];
}


- (void) setText:(NSString *)str forRow:(OOGUIRow)row
{
	if (RowInRange(row, rowRange))
	{
		[rowText replaceObjectAtIndex:row withObject:str];
	}
}


- (void) setText:(NSString *)str forRow:(OOGUIRow)row align:(OOGUIAlignment)alignment
{
	if (str != nil && RowInRange(row, rowRange))
	{
		[rowText replaceObjectAtIndex:row withObject:str];
		rowAlignment[row] = alignment;
	}
}


- (int) addLongText:(NSString *)str
	  startingAtRow:(OOGUIRow)row
			  align:(OOGUIAlignment)alignment
{

	if ([str rangeOfString:@"\n"].location != NSNotFound)
	{
		NSArray		*lines = [str componentsSeparatedByString:@"\n"];
		unsigned	i;
		for (i = 0; i < [lines count]; i++)
		{
			row = [self addLongText:[lines oo_stringAtIndex:i] startingAtRow:row align:alignment];
		}
		return row;
	}
	
	NSSize chSize = pixel_text_size;
	NSSize strsize = OORectFromString(str, 0.0f, 0.0f, chSize).size;
	if (strsize.width < size_in_pixels.width)
	{
		[self setText:str forRow:row align:alignment];
		return row + 1;
	}
	else
	{
		NSMutableArray	*words = ScanTokensFromString(str);
		NSMutableString	*string1 = [NSMutableString stringWithCapacity:256];
		NSMutableString	*string2 = [NSMutableString stringWithCapacity:256];
		strsize.width = 0.0f;
		while ((strsize.width < size_in_pixels.width)&&([words count] > 0))
		{
			[string1 appendString:(NSString *)[words objectAtIndex:0]];
			[string1 appendString:@" "];
			[words removeObjectAtIndex:0];
			strsize = OORectFromString(string1, 0.0f, 0.0f, chSize).size;
			if ([words count] > 0)
				strsize.width += OORectFromString((NSString *)[words objectAtIndex:0], 0.0f, 0.0f, chSize).size.width;
		}
		[string2 appendString:[words componentsJoinedByString:@" "]];
		[self setText:string1		forRow:row			align:alignment];
		return  [self addLongText:string2   startingAtRow:row+1	align:alignment];
	}
}


- (void) leaveLastLine
{
	unsigned i;
	for (i=0; i < n_rows-1; i++)
	{
		[rowText	replaceObjectAtIndex:i withObject:@""];
		[rowColor	replaceObjectAtIndex:i withObject:textColor];
		[rowKey		replaceObjectAtIndex:i withObject:@""];
		rowAlignment[i] = GUI_ALIGN_LEFT;
		rowFadeTime[i]	= 0.0f;
	}
	rowFadeTime[i]	= 0.4f; // fade the last line...
}


- (void) printLongText:(NSString *)str
				 align:(OOGUIAlignment) alignment
				 color:(OOColor *)text_color
			  fadeTime:(float)text_fade
				   key:(NSString *)text_key
			addToArray:(NSMutableArray *)text_array
{
	// print a multi-line message
	//
	if ([str rangeOfString:@"\n"].location != NSNotFound)
	{
		NSArray		*lines = [str componentsSeparatedByString:@"\n"];
		unsigned	i;
		for (i = 0; i < [lines count]; i++)
			[self printLongText:[lines oo_stringAtIndex:i] align:alignment color:text_color fadeTime:text_fade key:text_key addToArray:text_array];
		return;
	}
	
	OOGUIRow row = currentRow;
	if (row == (OOGUIRow)n_rows - 1)
		[self scrollUp:1];
	NSSize chSize = pixel_text_size;
	NSSize strsize = OORectFromString(str, 0.0f, 0.0f, chSize).size;
	if (strsize.width < size_in_pixels.width)
	{
		[self setText:str forRow:row align:alignment];
		if (text_color)
			[self setColor:text_color forRow:row];
		if (text_key)
			[self setKey:text_key forRow:row];
		rowFadeTime[row] = text_fade;
		if (currentRow < (OOGUIRow)n_rows - 1)
			currentRow++;
		if (text_array)
			[text_array addObject:str];
	}
	else
	{
		NSMutableArray	*words = ScanTokensFromString(str);
		NSMutableString	*string1 = [NSMutableString stringWithCapacity:256];
		NSMutableString	*string2 = [NSMutableString stringWithCapacity:256];	
		strsize.width = 0.0f;
		while ((strsize.width < size_in_pixels.width)&&([words count] > 0))
		{
			[string1 appendString:(NSString *)[words objectAtIndex:0]];
			[string1 appendString:@" "];
			[words removeObjectAtIndex:0];
			strsize = OORectFromString(string1, 0.0f, 0.0f, chSize).size;
			if ([words count] > 0)
				strsize.width += OORectFromString([words oo_stringAtIndex:0], 0.0f, 0.0f, chSize).size.width;
		}

		[self setText:string1		forRow:row			align:alignment];

		[string2 appendString:[words componentsJoinedByString:@" "]];
		if (text_color)
			[self setColor:text_color forRow:row];
		if (text_key)
			[self setKey:text_key forRow:row];
		if (text_array)
			[text_array addObject:string1];
		rowFadeTime[row] = text_fade;
		[self printLongText:string2 align:alignment color:text_color fadeTime:text_fade key:text_key addToArray:text_array];
	}
}


- (void) printLineNoScroll:(NSString *)str
					 align:(OOGUIAlignment)alignment
					  color:(OOColor *)text_color
				  fadeTime:(float)text_fade
					   key:(NSString *)text_key
				addToArray:(NSMutableArray *)text_array
{
	[self setText:str forRow:currentRow align:alignment];
	if (text_color)
		[self setColor:text_color forRow:currentRow];
	if (text_key)
		[self setKey:text_key forRow:currentRow];
	if (text_array)
		[text_array addObject:str];
	rowFadeTime[currentRow] = text_fade;
}


- (void) setArray:(NSArray *)arr forRow:(OOGUIRow)row
{
	if (RowInRange(row, rowRange))
		[rowText replaceObjectAtIndex:row withObject:arr];
}



- (void) insertItemsFromArray:(NSArray *)items
					 withKeys:(NSArray *)item_keys
					  intoRow:(OOGUIRow)row
						color:(OOColor *)text_color
{
	if (!items)
		return;
	if([items count] == 0)
		return;
	
	unsigned n_items = [items count];
	if ((item_keys)&&([item_keys count] != n_items))
	{
		// throw exception
		[NSException raise:@"ArrayLengthMismatchException"
					format:@"The NSArray sent as 'item_keys' to insertItemsFromArray::: must contain the same number of objects as the NSArray 'items'"];
	}

	unsigned i;
	for (i = n_rows; i >= row + n_items ; i--)
	{
		[self setKey:[self keyForRow:i - n_items] forRow:i];
		id	old_row_info = [self objectForRow:i - n_items];
		if ([old_row_info isKindOfClass:[NSArray class]])
			[self setArray:old_row_info forRow:i];
		if ([old_row_info isKindOfClass:[NSString class]])
			[self setText:(NSString *)old_row_info forRow:i];
	}
	for (i = 0; i < n_items; i++)
	{
		id new_row_info = [items objectAtIndex:i];
		if (text_color)
			[self setColor:text_color forRow: row + i];
		else
			[self setColor:textColor forRow: row + i];
		if ([new_row_info isKindOfClass:[NSArray class]])
			[self setArray:new_row_info forRow: row + i];
		if ([new_row_info isKindOfClass:[NSString class]])
			[self setText:(NSString *)new_row_info forRow: row + i];
		if (item_keys)
			[self setKey:[item_keys objectAtIndex:i] forRow: row + i];
		else
			[self setKey:@"" forRow: row + i];
	}
}


- (void) scrollUp:(int) how_much
{
	unsigned i;
	for (i = 0; i + how_much < n_rows; i++)
	{
		[rowText	replaceObjectAtIndex:i withObject:[rowText objectAtIndex:	i + how_much]];
		[rowColor	replaceObjectAtIndex:i withObject:[rowColor objectAtIndex:	i + how_much]];
		[rowKey		replaceObjectAtIndex:i withObject:[rowKey objectAtIndex:	i + how_much]];
		rowAlignment[i] = rowAlignment[i + how_much];
		rowFadeTime[i]	= rowFadeTime[i + how_much];
	}
	for (; i < n_rows; i++)
	{
		[rowText	replaceObjectAtIndex:i withObject:@""];
		[rowColor	replaceObjectAtIndex:i withObject:textColor];
		[rowKey		replaceObjectAtIndex:i withObject:@""];
		rowAlignment[i] = GUI_ALIGN_LEFT;
		rowFadeTime[i]	= 0.0f;
	}
}


- (void) clearBackground
{
	[self setBackgroundTextureDescriptor:nil];
	[self setForegroundTextureDescriptor:nil];
}


static OOTexture *TextureForGUITexture(NSDictionary *descriptor)
{
	return [OOTexture textureWithName:[descriptor oo_stringForKey:@"name"]
							 inFolder:@"Images"
							  options:kOOTextureDefaultOptions | kOOTextureNoShrink
						   anisotropy:kOOTextureDefaultAnisotropy
							  lodBias:kOOTextureDefaultLODBias];
}


/*
	Load a texture sprite given a descriptor. The caller owns a reference to
	the result.
*/
static OOTextureSprite *NewTextureSpriteWithDescriptor(NSDictionary *descriptor)
{
	OOTexture		*texture = nil;
	NSSize			size;
	
	texture = TextureForGUITexture(descriptor);
	if (texture == nil)  return nil;
	
	double specifiedWidth = [descriptor oo_doubleForKey:@"width" defaultValue:-INFINITY];
	double specifiedHeight = [descriptor oo_doubleForKey:@"height" defaultValue:-INFINITY];
	BOOL haveWidth = isfinite(specifiedWidth);
	BOOL haveHeight = isfinite(specifiedHeight);
	
	if (haveWidth && haveHeight)
	{
		// Both specified, use directly without calling -originalDimensions (which may block).
		size.width = specifiedWidth;
		size.height = specifiedHeight;
	}
	else
	{
		NSSize originalDimensions = [texture originalDimensions];
		
		if (haveWidth)
		{
			// Width specified, but not height; preserve aspect ratio.
			OOCGFloat ratio = originalDimensions.height / originalDimensions.width;
			size.width = specifiedWidth;
			size.height = ratio * size.width;
		}
		else if (haveHeight)
		{
			// Height specified, but not width; preserve aspect ratio.
			OOCGFloat ratio = originalDimensions.width / originalDimensions.height;
			size.height = specifiedHeight;
			size.width = ratio * size.height;
		}
		else
		{
			// Neither specified; use backwards-compatible behaviour.
			size = originalDimensions;
		}
	}
	
	return [[OOTextureSprite alloc] initWithTexture:texture size:size];
}


- (BOOL) setBackgroundTextureDescriptor:(NSDictionary *)descriptor
{
	[backgroundSprite autorelease];
	backgroundSprite = NewTextureSpriteWithDescriptor(descriptor);
	return backgroundSprite != nil;
}


- (BOOL) setForegroundTextureDescriptor:(NSDictionary *)descriptor
{
	[foregroundSprite autorelease];
	foregroundSprite = NewTextureSpriteWithDescriptor(descriptor);
	return foregroundSprite != nil;
}


- (BOOL) setBackgroundTextureKey:(NSString *)key
{
	return [self setBackgroundTextureDescriptor:[UNIVERSE screenTextureDescriptorForKey:key]];
}


- (BOOL) setForegroundTextureKey:(NSString *)key
{
	return [self setForegroundTextureDescriptor:[UNIVERSE screenTextureDescriptorForKey:key]];
}


- (BOOL) preloadGUITexture:(NSDictionary *)descriptor
{
	return TextureForGUITexture(descriptor) != nil;
}


- (NSDictionary *) textureDescriptorFromJSValue:(jsval)value
									  inContext:(JSContext *)context
							  callerDescription:(NSString *)callerDescription
{
	OOJS_PROFILE_ENTER
	
	NSDictionary	*result = nil;
	
	if (JSVAL_IS_OBJECT(value))
	{
		// Null may be used to indicate no texture.
		if (JSVAL_IS_NULL(value))  return [NSDictionary dictionary];
		
		JSObject *objValue = JSVAL_TO_OBJECT(value);
		
		if (OOJSGetClass(context, objValue) != [[OOJavaScriptEngine sharedEngine] stringClass])
		{
			result = OOJSDictionaryFromJSObject(context, objValue);
		}
	}
	
	if (result == nil)
	{
		NSString *name = OOStringFromJSValue(context, value);
		if (name != nil)
		{
			result = [NSDictionary dictionaryWithObject:name forKey:@"name"];
			if ([name length] == 0)  return result;	// Explicit empty string may be used to indicate no texture.
		}
	}
	
	// Start loading the texture, and return nil if it doesn't exist.
	if (result != nil && ![self preloadGUITexture:result])
	{
		OOJSReportWarning(context, @"%@: texture \"%@\" could not be found.", callerDescription, [result oo_stringForKey:@"name"]);
		result = nil;
	}
	
	return result;
	
	OOJS_PROFILE_EXIT
}


- (void) setStatusPage:(int)pageNum
{
	if (pageNum==0) 
		statusPage=1;
	else 
		statusPage += pageNum;
}


- (void) drawEqptList:(NSArray *)eqptList z:(GLfloat)z 
{
	if ([eqptList count] == 0) return;
	
	int				first_row = STATUS_EQUIPMENT_FIRST_ROW;
	int				items_per_column = STATUS_EQUIPMENT_MAX_ROWS;

	int				first_y = 40;	// first_row =10 :-> 40  - first_row=11 -> 24 etc...
	int				items_count = [eqptList count];
	int				page_count=1;
	int				i, start;
	NSArray			*info = nil;
	NSString		*name = nil;
	BOOL			damaged;
	
	// Paging calculations. Assuming 10 lines we get - one page:20 items per page (ipp)
	// two pages: 18 ipp - three+ pages:  1st & last 18pp,  middle pages 16ipp
	
	i = items_per_column * 2 + 2;
	if (items_count > i) // don't fit in one page?
	{
		[UNIVERSE setDisplayCursor: YES];
		i = items_per_column * 4; // total items in the first and last pages
		items_per_column--; // for all the middle pages.
		if (items_count <= i) // two pages
		{
			page_count++;
			if (statusPage == 1) start=0;
			else
			{
				statusPage = 2;
				start = i/statusPage; // for the for loop
			}
		}
		else // three or more
		{
			page_count = ceil((float)(items_count-i)/(items_per_column*2)) + 2;
			statusPage = OOClampInteger(statusPage, 1, page_count);
			start = (statusPage == 1) ? 0 : (statusPage-1) * items_per_column * 2 + 2;
		}
	}
	else
	{
		statusPage=page_count; // one page
		start=0;
	}
	
	if (statusPage > 1)
	{
		[self setColor:[OOColor greenColor] forRow:first_row];
		[self setArray:[NSArray arrayWithObjects:DESC(@"gui-back"),  @"", @" <-- ",nil] forRow:first_row];
		[self setKey:GUI_KEY_OK forRow:first_row];
		first_y -= 16; // start 1 row down!
		if (statusPage == page_count)
		{
			[self setSelectableRange:NSMakeRange(first_row, 1)];
			[self setSelectedRow:first_row];
		}
	}
	if (statusPage < page_count)
	{
		[self setColor:[OOColor greenColor] forRow:first_row + STATUS_EQUIPMENT_MAX_ROWS];
		[self setArray:[NSArray arrayWithObjects:DESC(@"gui-more"),  @"", @" --> ",nil] forRow:first_row + STATUS_EQUIPMENT_MAX_ROWS];
		[self setKey:GUI_KEY_OK forRow:first_row + STATUS_EQUIPMENT_MAX_ROWS];
		if (statusPage == 1)
		{
			[self setSelectableRange:NSMakeRange(first_row + STATUS_EQUIPMENT_MAX_ROWS, 1)];
			[self setSelectedRow:first_row + STATUS_EQUIPMENT_MAX_ROWS];
		}
	}
	if (statusPage > 1 && statusPage < page_count)
	{
		[self setSelectableRange:NSMakeRange(first_row, first_row + STATUS_EQUIPMENT_MAX_ROWS)];
		// default selected row to 'More -->' if we are looking at one of the middle pages
		if ([self selectedRow] == -1)  [self setSelectedRow:first_row + STATUS_EQUIPMENT_MAX_ROWS];
	}

	if (statusPage == 1 || statusPage == page_count) items_per_column++;
	items_count = OOClampInteger(items_count, 1, start + items_per_column * 2);
	for (i=start; i < items_count; i++)
	{
		info = [eqptList objectAtIndex:i];
		name = [info oo_stringAtIndex:0];
		damaged = ![info oo_boolAtIndex:1];
		if (damaged)  glColor4f (1.0f, 0.5f, 0.0f, 1.0f); // Damaged items  show up  orange.
		else glColor4f (1.0f, 1.0f, 0.0f, 1.0f);	// Normal items in yellow.
		if([name length] > 42)  name =[[name substringToIndex:40] stringByAppendingString:@"..."];
		if (i - start < items_per_column)
		{
			OODrawString (name, -220, first_y - 16 * (i - start), z, NSMakeSize(15, 15));
		}
		else
		{
			OODrawString (name, 50, first_y - 16 * (i - items_per_column - start), z, NSMakeSize(15, 15));
		}
	}
}


- (void) drawGUIBackground
{
	GLfloat x = drawPosition.x;
	GLfloat y = drawPosition.y;
	GLfloat z = [[UNIVERSE gameView] display_z];

	if (backgroundSprite!=nil)
	{
		[backgroundSprite blitBackgroundCentredToX:x Y:y Z:z alpha:1.0f];
	}
}


- (int) drawGUI:(GLfloat) alpha drawCursor:(BOOL) drawCursor
{
	GLfloat x = drawPosition.x;
	GLfloat y = drawPosition.y;
	GLfloat z = [[UNIVERSE gameView] display_z];
	
	if (alpha > 0.05f)
	{
		PlayerEntity* player = PLAYER;
		
		[self drawGLDisplay:x - 0.5f * size_in_pixels.width :y - 0.5f * size_in_pixels.height :z :alpha];
		
		if (self == [UNIVERSE gui])
		{
			if ([player guiScreen] == GUI_SCREEN_SHORT_RANGE_CHART)
				[self drawStarChart:x - 0.5f * size_in_pixels.width :y - 0.5f * size_in_pixels.height :z :alpha];
			if ([player guiScreen] == GUI_SCREEN_LONG_RANGE_CHART)
			{
				[self drawGalaxyChart:x - 0.5f * size_in_pixels.width :y - 0.5f * size_in_pixels.height :z :alpha];
			}
			if ([player guiScreen] == GUI_SCREEN_STATUS)
			{
				[self drawEqptList:[player equipmentList] z:z ];
			}
		}
		
		if (fade_sign)
		{
			fade_alpha += (float)(fade_sign * [UNIVERSE getTimeDelta]);
			if (fade_alpha < 0.05f)	// done fading out
			{
				fade_alpha = 0.0f;
				fade_sign = 0.0f;
			}
			if (fade_alpha > 1.0f)	// done fading in
			{
				fade_alpha = 1.0f;
				fade_sign = 0.0f;
			}
		}
	}
	
	int cursor_row = 0;

	if (drawCursor)
	{
		NSPoint vjpos = [[UNIVERSE gameView] virtualJoystickPosition];
		double cursor_x = size_in_pixels.width * vjpos.x;
		if (cursor_x < -size_in_pixels.width * 0.5)  cursor_x = -size_in_pixels.width * 0.5f;
		if (cursor_x > size_in_pixels.width * 0.5)   cursor_x = size_in_pixels.width * 0.5f;
		double cursor_y = -size_in_pixels.height * vjpos.y;
		if (cursor_y < -size_in_pixels.height * 0.5)  cursor_y = -size_in_pixels.height * 0.5f;
		if (cursor_y > size_in_pixels.height * 0.5)   cursor_y = size_in_pixels.height * 0.5f;
		
		cursor_row = 1 + (float)floor((0.5f * size_in_pixels.height - pixel_row_start - cursor_y) / pixel_row_height);
		
		GLfloat h1 = 3.0f;
		GLfloat h3 = 9.0f;
		OOGL(glColor4f(0.2f, 0.2f, 1.0f, 0.5f));
		OOGL(glLineWidth(2.0f));
		
		cursor_x += x;
		cursor_y += y;
		[[UNIVERSE gameView] setVirtualJoystick:cursor_x/size_in_pixels.width :-cursor_y/size_in_pixels.height];

		OOGLBEGIN(GL_LINES);
			glVertex3f((float)cursor_x - h1, (float)cursor_y, z);	glVertex3f((float)cursor_x - h3, (float)cursor_y, z);
			glVertex3f((float)cursor_x + h1, (float)cursor_y, z);	glVertex3f((float)cursor_x + h3, (float)cursor_y, z);
			glVertex3f((float)cursor_x, (float)cursor_y - h1, z);	glVertex3f((float)cursor_x, (float)cursor_y - h3, z);
			glVertex3f((float)cursor_x, (float)cursor_y + h1, z);	glVertex3f((float)cursor_x, (float)cursor_y + h3, z);
		OOGLEND();
		OOGL(glLineWidth(1.0f));
		
	}
	
	return cursor_row;
}


- (void) drawGLDisplay:(GLfloat)x :(GLfloat)y :(GLfloat)z :(GLfloat) alpha
{
	NSSize		strsize;
	unsigned	i;
	OOTimeDelta	delta_t = [UNIVERSE getTimeDelta];
	NSSize		characterSize = pixel_text_size;
	NSSize		titleCharacterSize = pixel_title_size;
	
	// do backdrop
	//
	if (backgroundColor)
	{
		OOGL(glColor4f([backgroundColor redComponent], [backgroundColor greenComponent], [backgroundColor blueComponent], alpha * [backgroundColor alphaComponent]));
		OOGLBEGIN(GL_QUADS);
			glVertex3f(x + 0.0f,					y + 0.0f,					z);
			glVertex3f(x + size_in_pixels.width,	y + 0.0f,					z);
			glVertex3f(x + size_in_pixels.width,	y + size_in_pixels.height,	z);
			glVertex3f(x + 0.0f,					y + size_in_pixels.height,	z);
		OOGLEND();
	}
	
	// show the 'foreground', aka overlay!
	
	if (foregroundSprite != nil)
	{
		[foregroundSprite blitCentredToX:x + 0.5f * size_in_pixels.width Y:y + 0.5f * size_in_pixels.height Z:z alpha:alpha];
	}
	
	if (!RowInRange(selectedRow, selectableRange))
		selectedRow = -1;   // out of Range;
	
	////
	// drawing operations here
	
	if (title != nil)
	{
		//
		// draw the title
		//
		strsize = OORectFromString(title, 0.0f, 0.0f, titleCharacterSize).size;
		OOGL(glColor4f(1.0f, 0.0f, 0.0f, alpha));	// red
		OODrawString(title, x + pixel_row_center - strsize.width/2.0, y + size_in_pixels.height - pixel_title_size.height, z, titleCharacterSize);
		
		// draw a horizontal divider
		//
		OOGL(glColor4f(0.75f, 0.75f, 0.75f, alpha));	// 75% gray
		OOGLBEGIN(GL_QUADS);
			glVertex3f(x + 0,					y + size_in_pixels.height - pixel_title_size.height + 4,	z);
			glVertex3f(x + size_in_pixels.width,	y + size_in_pixels.height - pixel_title_size.height + 4,	z);
			glVertex3f(x + size_in_pixels.width,	y + size_in_pixels.height - pixel_title_size.height + 2,		z);
			glVertex3f(x + 0,					y + size_in_pixels.height - pixel_title_size.height + 2,		z);
		OOGLEND();
	}
	
	// draw each row of text
	//
	for (i = 0; i < n_rows; i++)
	{
		OOColor* row_color = (OOColor *)[rowColor objectAtIndex:i];
		GLfloat row_alpha = alpha;
		if (rowFadeTime[i] > 0.0f)
		{
			rowFadeTime[i] -= (float)delta_t;
			if (rowFadeTime[i] <= 0.0f)
			{
				[rowText replaceObjectAtIndex:i withObject:@""];
				rowFadeTime[i] = 0.0f;
			}
			if ((rowFadeTime[i] > 0.0f)&&(rowFadeTime[i] < 1.0))
				row_alpha *= rowFadeTime[i];
		}
		glColor4f([row_color redComponent], [row_color greenComponent], [row_color blueComponent], row_alpha);
		
		if ([[rowText objectAtIndex:i] isKindOfClass:[NSString class]])
		{
			NSString*   text = (NSString *)[rowText objectAtIndex:i];
			if (![text isEqual:@""])
			{
				strsize = OORectFromString(text, 0.0f, 0.0f, characterSize).size;
				switch (rowAlignment[i])
				{
					case GUI_ALIGN_LEFT :
						rowPosition[i].x = 0.0f;
						break;
					case GUI_ALIGN_RIGHT :
						rowPosition[i].x = size_in_pixels.width - strsize.width;
						break;
					case GUI_ALIGN_CENTER :
						rowPosition[i].x = (size_in_pixels.width - strsize.width)/2.0f;
						break;
				}
				if (i == (unsigned)selectedRow)
				{
					NSRect block = OORectFromString(text, x + rowPosition[i].x + 2, y + rowPosition[i].y + 2, characterSize);
					OOGL(glColor4f(1.0f, 0.0f, 0.0f, row_alpha));	// red
					OOGLBEGIN(GL_QUADS);
						glVertex3f(block.origin.x,						block.origin.y,						z);
						glVertex3f(block.origin.x + block.size.width,	block.origin.y,						z);
						glVertex3f(block.origin.x + block.size.width,	block.origin.y + block.size.height,	z);
						glVertex3f(block.origin.x,						block.origin.y + block.size.height,	z);
					OOGLEND();
					OOGL(glColor4f(0.0f, 0.0f, 0.0f, row_alpha));	// black
				}
				OODrawString(text, x + rowPosition[i].x, y + rowPosition[i].y, z, characterSize);
				
				// draw cursor at end of current Row
				//
				if ((showTextCursor)&&(i == (unsigned)currentRow))
				{
					NSRect	tr = OORectFromString(text, 0.0f, 0.0f, characterSize);
					NSPoint cu = NSMakePoint(x + rowPosition[i].x + tr.size.width + 0.2f * characterSize.width, y + rowPosition[i].y);
					tr.origin = cu;
					tr.size.width = 0.5f * characterSize.width;
					GLfloat g_alpha = 0.5f * (1.0f + (float)sin(6 * [UNIVERSE getTime]));
					OOGL(glColor4f(1.0f, 0.0f, 0.0f, row_alpha * g_alpha));	// red
					OOGLBEGIN(GL_QUADS);
						glVertex3f(tr.origin.x,					tr.origin.y,					z);
						glVertex3f(tr.origin.x + tr.size.width,	tr.origin.y,					z);
						glVertex3f(tr.origin.x + tr.size.width,	tr.origin.y + tr.size.height,	z);
						glVertex3f(tr.origin.x,					tr.origin.y + tr.size.height,	z);
					OOGLEND();
				}
			}
		}
		if ([[rowText objectAtIndex:i] isKindOfClass:[NSArray class]])
		{
			unsigned j;
			NSArray*	array = (NSArray *)[rowText objectAtIndex:i];
			unsigned max_columns=[array count] < n_columns ? [array count] : n_columns;
			BOOL isLeftAligned;
			
			for (j = 0; j < max_columns ; j++)
			{
				NSString*   text = [array oo_stringAtIndex:j];
				if ([text length] != 0)
				{
					isLeftAligned=tabStops[j]>=0;
					rowPosition[i].x = abs(tabStops[j]);
					NSRect block = OORectFromString(text, x + rowPosition[i].x + 2, y + rowPosition[i].y + 2, characterSize);
					if(!isLeftAligned)
					{
						rowPosition[i].x -=block.size.width+6;
						block = OORectFromString(text, x + rowPosition[i].x, y + rowPosition[i].y + 2, characterSize);
						block.size.width+=2;
					}					
					if (i == (unsigned)selectedRow)
					{
						OOGL(glColor4f(1.0f, 0.0f, 0.0f, row_alpha));	// red
						OOGLBEGIN(GL_QUADS);
							glVertex3f(block.origin.x,						block.origin.y,						z);
							glVertex3f(block.origin.x + block.size.width,	block.origin.y,						z);
							glVertex3f(block.origin.x + block.size.width,	block.origin.y + block.size.height,	z);
							glVertex3f(block.origin.x,						block.origin.y + block.size.height,	z);
						OOGLEND();
						OOGL(glColor4f(0.0f, 0.0f, 0.0f, row_alpha));	// black
					}
					OODrawString(text, x + rowPosition[i].x, y + rowPosition[i].y, z, characterSize);
				}
			}
		}
	}
	
	[OOTexture applyNone];
}


- (void) drawCrossHairsWithSize:(GLfloat) size x:(GLfloat)x y:(GLfloat)y z:(GLfloat)z
{
	OOGLBEGIN(GL_QUADS);
		glVertex3f(x - 1,	y - size,	z);
		glVertex3f(x + 1,	y - size,	z);
		glVertex3f(x + 1,	y + size,	z);
		glVertex3f(x - 1,	y + size,	z);
		glVertex3f(x - size,	y - 1,	z);
		glVertex3f(x + size,	y - 1,	z);
		glVertex3f(x + size,	y + 1,	z);
		glVertex3f(x - size,	y + 1,	z);
	OOGLEND();
}


- (void) drawStarChart:(GLfloat)x :(GLfloat)y :(GLfloat)z :(GLfloat) alpha
{
	PlayerEntity* player = PLAYER;

	if (!player)
		return;

	NSPoint	galaxy_coordinates = [player galaxy_coordinates];
	NSPoint	cursor_coordinates = [player cursor_coordinates];
	NSPoint	cu;
	
	double fuel = 35.0 * [player dialFuel];
	
	Random_Seed g_seed;
	double		hcenter = size_in_pixels.width/2.0;
	double		vcenter = 160.0f;
	double		hscale = size_in_pixels.width / 64.0;
	double		vscale = -size_in_pixels.height / 128.0;
	double		hoffset = hcenter - galaxy_coordinates.x*hscale;
	double		voffset = size_in_pixels.height - pixel_title_size.height - 5 - vcenter - galaxy_coordinates.y*vscale;
	int			i;
	NSPoint		star;
	
	if ((abs(cursor_coordinates.x-galaxy_coordinates.x)>=20)||(abs(cursor_coordinates.y-galaxy_coordinates.y)>=38))
		cursor_coordinates = galaxy_coordinates;	// home
	
	// get a list of systems marked as contract destinations
	NSArray* markedDestinations = [player markedDestinations];
	
	// get present location
	cu = NSMakePoint((float)(hscale*galaxy_coordinates.x+hoffset),(float)(vscale*galaxy_coordinates.y+voffset));

	if ([player hasHyperspaceMotor])
	{
		// draw fuel range circle
		OOGL(glColor4f(0.0f, 1.0f, 0.0f, alpha));	//	green
		OOGL(glLineWidth(2.0f));
		GLDrawOval(x + cu.x, y + cu.y, z, NSMakeSize((float)(fuel*hscale), 2*(float)(fuel*vscale)), 5);
	}
		
	// draw marks and stars
	//
	OOGL(glLineWidth(1.5f));
	OOGL(glColor4f(1.0f, 1.0f, 0.75f, alpha));	// pale yellow

	for (i = 0; i < 256; i++)
	{
		g_seed = [UNIVERSE systemSeedForSystemNumber:i];
		
		int dx, dy;
		float blob_size = 4.0f + 0.5f * (g_seed.f & 15);
				
		star.x = (float)(g_seed.d * hscale + hoffset);
		star.y = (float)(g_seed.b * vscale + voffset);
		
		dx = abs(galaxy_coordinates.x - g_seed.d);
		dy = abs(galaxy_coordinates.y - g_seed.b);
		
		if ((dx < 20)&&(dy < 38))
		{
			if ([markedDestinations oo_boolAtIndex:i])	// is marked
			{
				GLfloat mark_size = 0.5f * blob_size + 2.5f;
				OOGL(glColor4f(1.0f, 0.0f, 0.0f, alpha));	// red
				OOGLBEGIN(GL_LINES);
					glVertex3f(x + star.x - mark_size,	y + star.y - mark_size,	z);
					glVertex3f(x + star.x + mark_size,	y + star.y + mark_size,	z);
					glVertex3f(x + star.x - mark_size,	y + star.y + mark_size,	z);
					glVertex3f(x + star.x + mark_size,	y + star.y - mark_size,	z);
				OOGLEND();
				OOGL(glColor4f(1.0f, 1.0f, 0.75f, alpha));	// pale yellow
			}
			GLDrawFilledOval(x + star.x, y + star.y, z, NSMakeSize(blob_size,blob_size), 15);
		}
	}
	
	// draw names
	//
	// Cache nearby systems so that [UNIVERSE generateSystemData:] does not get called on every frame
	// Caching code submitted by Y A J, 20091022
	static Random_Seed saved_galaxy_seed;
	static NSPoint saved_galaxy_coordinates;
	static struct saved_system
	{
		int seed_d, seed_b;
		int tec, eco, gov;
		NSString* p_name;
	} nearby_systems[ 256 ];
	static int num_nearby_systems;

	if( !equal_seeds( [player galaxy_seed], saved_galaxy_seed ) ||
		galaxy_coordinates.x != saved_galaxy_coordinates.x ||
		galaxy_coordinates.y != saved_galaxy_coordinates.y )
	{
		// saved systems are stale; recompute
		for (i = 0; i < num_nearby_systems; i++)
			[nearby_systems[ i ].p_name release];

		num_nearby_systems = 0;
		for (i = 0; i < 256; i++)
		{
			g_seed = [UNIVERSE systemSeedForSystemNumber:i];
		
			int dx, dy;
		
			dx = abs(galaxy_coordinates.x - g_seed.d);
			dy = abs(galaxy_coordinates.y - g_seed.b);
		
			if ((dx < 20)&&(dy < 38))
			{
				NSDictionary* sys_info = [UNIVERSE generateSystemData:g_seed];
				nearby_systems[ num_nearby_systems ].seed_d = g_seed.d;
				nearby_systems[ num_nearby_systems ].seed_b = g_seed.b;
				nearby_systems[ num_nearby_systems ].tec = [sys_info oo_intForKey:KEY_TECHLEVEL];
				nearby_systems[ num_nearby_systems ].eco = [sys_info oo_intForKey:KEY_ECONOMY];
				nearby_systems[ num_nearby_systems ].gov = [sys_info oo_intForKey:KEY_GOVERNMENT];
				nearby_systems[ num_nearby_systems ].p_name = [[sys_info oo_stringForKey:KEY_NAME] retain];
				num_nearby_systems++;
			}
		}
		saved_galaxy_seed = [player galaxy_seed];
		saved_galaxy_coordinates = galaxy_coordinates;
	}
	
	OOGL(glColor4f(1.0f, 1.0f, 0.0f, alpha));	// yellow
	
	Random_Seed target = [PLAYER target_system_seed];	
	NSString *targetName = [UNIVERSE getSystemName:target];
	
	int targetIdx = -1;
	struct saved_system *sys;
	
	for (i = 0; i < num_nearby_systems; i++)
	{
		sys = nearby_systems + i;
		
		star.x = (float)(sys->seed_d * hscale + hoffset);
		star.y = (float)(sys->seed_b * vscale + voffset);
		if (sys->seed_d == target.d && sys->seed_b == target.b)
			if ([sys->p_name isEqualToString:targetName]) targetIdx = i; // Distinguish between overlapping systems! (e.g. Divees & Tezabi in galaxy 5)
		
		if (![player showInfoFlag])
		{
			OODrawString(sys->p_name, x + star.x + 2.0, y + star.y, z, NSMakeSize(pixel_row_height,pixel_row_height));
		}
		else
		{
			OODrawPlanetInfo(sys->gov, sys->eco, sys->tec, x + star.x + 2.0, y + star.y + 2.0, z, NSMakeSize(pixel_row_height,pixel_row_height));
		}
	}
	
	// highlight the name of the currently selected system
	//
	if( targetIdx != -1 )
	{
		sys = nearby_systems + targetIdx;
		star.x = (float)(sys->seed_d * hscale + hoffset);
		star.y = (float)(sys->seed_b * vscale + voffset);

		if (![player showInfoFlag])
		{
			OODrawHilightedString(sys->p_name, x + star.x + 2.0, y + star.y, z, NSMakeSize(pixel_row_height,pixel_row_height));
		}
		else
		{
			OODrawHilightedPlanetInfo(sys->gov, sys->eco, sys->tec, x + star.x + 2.0, y + star.y + 2.0, z, NSMakeSize(pixel_row_height,pixel_row_height));
		}
	}
	
	// draw cross-hairs over current location
	//
	OOGL(glColor4f(0.0f, 1.0f, 0.0f, alpha));	//	green
	[self drawCrossHairsWithSize:14 x:x + cu.x y:y + cu.y z:z];
	
	// draw cross hairs over cursor
	//
	OOGL(glColor4f(1.0f, 0.0f, 0.0f, alpha));	//	red
	cu = NSMakePoint((float)(hscale*cursor_coordinates.x+hoffset),(float)(vscale*cursor_coordinates.y+voffset));
	[self drawCrossHairsWithSize:7 x:x + cu.x y:y + cu.y z:z];
}


- (Random_Seed) targetNextFoundSystem:(int)direction // +1 , 0 , -1
{
	Random_Seed sys = [PLAYER target_system_seed];
	if ([PLAYER guiScreen] != GUI_SCREEN_LONG_RANGE_CHART) return sys;
	
	BOOL		*systemsFound = [UNIVERSE systemsFound];
	unsigned 	i, first = 0, last = 0, count = 0;
	int 		systemIndex = foundSystem + direction;

	if (direction == 0) systemIndex = 0;
	
	for (i = 0; i <= kOOMaximumSystemID; i++)
	{
		if (systemsFound[i])
		{
			if (count == 0)
			{
				first = last = i;
			}
			else
			{
				last = i;
			}
			if (systemIndex == (int)count) sys = [UNIVERSE systemSeedForSystemNumber:i];
			count++;
		}
	}

	if (count == 0) return sys; // empty systemFound list.
	
	// loop back if needed.
	if (systemIndex < 0)
	{
		systemIndex = count - 1;
		sys = [UNIVERSE systemSeedForSystemNumber:last];
	}
	if (systemIndex >= (int)count)
	{
		systemIndex = 0;
		sys = [UNIVERSE systemSeedForSystemNumber:first];
	}
	
	foundSystem = systemIndex;
	return sys;
}


- (void) drawGalaxyChart:(GLfloat)x :(GLfloat)y :(GLfloat)z :(GLfloat) alpha
{
	PlayerEntity*	player = PLAYER;
	NSPoint			galaxy_coordinates = [player galaxy_coordinates];
	NSPoint			cursor_coordinates = [player cursor_coordinates];
	Random_Seed		galaxy_seed = [player galaxy_seed];

	double fuel = 35.0 * [player dialFuel];

	// get a list of systems marked as contract destinations
	NSArray		*markedDestinations = [player markedDestinations];
	
	BOOL		*systemsFound = [UNIVERSE systemsFound];
	
	NSPoint		star, cu;
	
	Random_Seed g_seed;
	double		hscale = size_in_pixels.width / 256.0;
	double		vscale = -1.0 * size_in_pixels.height / 512.0;
	double		hoffset = 0.0f;
	double		voffset = size_in_pixels.height - pixel_title_size.height - 5;
	OORouteType	advancedNavArrayMode = OPTIMIZED_BY_NONE;
	BOOL		routeExists = YES;
	
	int			i;
	double		distance, time;
	
	if (showAdvancedNavArray) advancedNavArrayMode = [[UNIVERSE gameView] isCtrlDown] ? OPTIMIZED_BY_TIME : OPTIMIZED_BY_JUMPS;

	if (advancedNavArrayMode != OPTIMIZED_BY_NONE && ![UNIVERSE strict] && [player hasEquipmentItem:@"EQ_ADVANCED_NAVIGATIONAL_ARRAY"])
	{
		int planetNumber = [UNIVERSE findSystemNumberAtCoords:galaxy_coordinates withGalaxySeed:galaxy_seed];
		int destNumber = [UNIVERSE findSystemNumberAtCoords:cursor_coordinates withGalaxySeed:galaxy_seed];
		NSDictionary* routeInfo = [UNIVERSE routeFromSystem:planetNumber toSystem:destNumber optimizedBy:advancedNavArrayMode];
		
		if (!routeInfo)  routeExists = NO;

		[self drawAdvancedNavArrayAtX:x y:y z:z alpha:alpha usingRoute: (planetNumber != destNumber ? (id)routeInfo : nil) optimizedBy:advancedNavArrayMode];
		if (routeExists)
		{
			distance = [routeInfo oo_doubleForKey:@"distance"];
			time = [routeInfo oo_doubleForKey:@"time"];
		}
	}
	else
	{
		Random_Seed dest = [UNIVERSE findSystemAtCoords:cursor_coordinates withGalaxySeed:galaxy_seed];
		distance = distanceBetweenPlanetPositions(dest.d,dest.b,galaxy_coordinates.x,galaxy_coordinates.y);
		time = distance * distance;
	}

	if (routeExists)
	{
		// distance-f & est-travel-time-f are identical between short & long range charts in standard Oolite, however can be alterered separately via OXPs
		[self setText:[NSString stringWithFormat:ExpandDescriptionForCurrentSystem(@"[long-range-chart-distance-f]"), distance] forRow:18];
		NSString *travelTimeLine = @"";
		if (advancedNavArrayMode != OPTIMIZED_BY_NONE && distance > 0)
		{
			travelTimeLine = [NSString stringWithFormat:ExpandDescriptionForCurrentSystem(@"[long-range-chart-est-travel-time-f]"), time];
		}
		[self setText:travelTimeLine forRow:19];
	}
	else
	{
		[self setText:DESC(@"long-range-chart-system-unreachable")  forRow:18];
	}
	
	OOGL(glColor4f(0.0f, 1.0f, 0.0f, alpha));	//	green
	OOGL(glLineWidth(2.0f));
	cu = NSMakePoint((float)(hscale*galaxy_coordinates.x+hoffset),(float)(vscale*galaxy_coordinates.y+voffset));
	
	if ([player hasHyperspaceMotor])
	{
		// draw fuel range circle
		GLDrawOval(x + cu.x, y + cu.y, z, NSMakeSize((float)(fuel*hscale), 2*(float)(fuel*vscale)), 5);
	}
	
	// draw cross-hairs over current location
	//
	[self drawCrossHairsWithSize:12 x:x + cu.x y:y + cu.y z:z];
	
	// draw cross hairs over cursor
	//
	OOGL(glColor4f(1.0f, 0.0f, 0.0f, alpha));	//	red
	cu = NSMakePoint((float)(hscale*cursor_coordinates.x+hoffset),(float)(vscale*cursor_coordinates.y+voffset));
	[self drawCrossHairsWithSize:6 x:x + cu.x y:y + cu.y z:z];
	
	// draw marks
	//
	OOGL(glLineWidth(1.5f));
	OOGL(glColor4f(1.0f, 0.0f, 0.0f, alpha));
	for (i = 0; i < 256; i++)
	{
		g_seed = [UNIVERSE systemSeedForSystemNumber:i];
		BOOL mark = [markedDestinations oo_boolAtIndex:i];
		if (mark)
		{
			star.x = (float)(g_seed.d * hscale + hoffset);
			star.y = (float)(g_seed.b * vscale + voffset);
			OOGLBEGIN(GL_LINES);
				glVertex3f(x + star.x - 2.5f,	y + star.y - 2.5f,	z);
				glVertex3f(x + star.x + 2.5f,	y + star.y + 2.5f,	z);
				glVertex3f(x + star.x - 2.5f,	y + star.y + 2.5f,	z);
				glVertex3f(x + star.x + 2.5f,	y + star.y - 2.5f,	z);
			OOGLEND();
		}
	}
	
	// draw stars
	//
	OOGL(glColor4f(1.0f, 1.0f, 1.0f, alpha));
	OOGLBEGIN(GL_QUADS);
	for (i = 0; i < 256; i++)
	{
		g_seed = [UNIVERSE systemSeedForSystemNumber:i];
		
		star.x = (float)(g_seed.d * hscale + hoffset);
		star.y = (float)(g_seed.b * vscale + voffset);

		float sz = (4.0f + 0.5f * (0x03 | (g_seed.f & 0x0f))) / 7.0f;
		
		glVertex3f(x + star.x, y + star.y + sz, z);
		glVertex3f(x + star.x + sz,	y + star.y, z);
		glVertex3f(x + star.x, y + star.y - sz, z);
		glVertex3f(x + star.x - sz,	y + star.y, z);
	}
	OOGLEND();
		
	// draw found stars and captions
	//
	OOGL(glLineWidth(1.5f));
	OOGL(glColor4f(0.0f, 1.0f, 0.0f, alpha));
	int n_matches = 0, foundIndex = -1;
	
	for (i = 0; i < 256; i++) if (systemsFound[i])
	{
		if(foundSystem == n_matches) foundIndex = i;
		n_matches++;
	}
	
	if (n_matches == 0)
	{
		foundSystem = 0;
	}
	else
	{
		BOOL drawNames = n_matches < 4;
		for (i = 0; i < 256; i++)
		{
			BOOL mark = systemsFound[i];
			g_seed = [UNIVERSE systemSeedForSystemNumber:i];
			if (mark)
			{
				star.x = (float)(g_seed.d * hscale + hoffset);
				star.y = (float)(g_seed.b * vscale + voffset);
				OOGLBEGIN(GL_LINE_LOOP);
					glVertex3f(x + star.x - 2.0f,	y + star.y - 2.0f,	z);
					glVertex3f(x + star.x + 2.0f,	y + star.y - 2.0f,	z);
					glVertex3f(x + star.x + 2.0f,	y + star.y + 2.0f,	z);
					glVertex3f(x + star.x - 2.0f,	y + star.y + 2.0f,	z);
				OOGLEND();
				if (i == foundIndex || n_matches == 1)
				{
					if (n_matches == 1) foundSystem = 0;
					OOGL(glColor4f(0.0f, 1.0f, 1.0f, alpha));
					OODrawString([UNIVERSE systemNameIndex:i] , x + star.x + 2.0, y + star.y - 10.0f, z, NSMakeSize(10,10));
					OOGL(glColor4f(0.0f, 1.0f, 0.0f, alpha));
				}
				else if (drawNames)
					OODrawString([UNIVERSE systemNameIndex:i] , x + star.x + 2.0, y + star.y - 10.0f, z, NSMakeSize(10,10));
			}
		}
	}
	
	// draw bottom horizontal divider
	//
	OOGL(glColor4f(0.75f, 0.75f, 0.75f, alpha));	// 75% gray
	OOGLBEGIN(GL_QUADS);
		glVertex3f(x + 0, (float)(y + voffset + 260.0f*vscale + 0),	z);
		glVertex3f(x + size_in_pixels.width, y + (float)(voffset + 260.0f*vscale + 0), z);
		glVertex3f(x + size_in_pixels.width, (float)(y + voffset + 260.0f*vscale - 2), z);
		glVertex3f(x + 0, (float)(y + voffset + 260.0f*vscale - 2), z);
	OOGLEND();

}


// Advanced Navigation Array -- galactic chart route mapping - contributed by Nikos Barkas (another_commander).
- (void) drawAdvancedNavArrayAtX:(float)x y:(float)y z:(float)z alpha:(float)alpha usingRoute:(NSDictionary *) routeInfo optimizedBy:(OORouteType) optimizeBy
{
	PlayerEntity	*player = PLAYER;
	Random_Seed		g_seed, g_seed2;
	int				i, j;
	double			hscale = size_in_pixels.width / 256.0;
	double			vscale = -1.0 * size_in_pixels.height / 512.0;
	double			hoffset = 0.0f;
	double			voffset = size_in_pixels.height - pixel_title_size.height - 5;
	NSPoint			star, star2 = NSZeroPoint;
	
	OOGL(glColor4f(0.25f, 0.25f, 0.25f, alpha));
	
	OOGLBEGIN(GL_LINES);
	for (i = 0; i < 256; i++) for (j = i + 1; j < 256; j++)
	{
		g_seed = [UNIVERSE systemSeedForSystemNumber:i];
		g_seed2 = [UNIVERSE systemSeedForSystemNumber:j];
		
		star.x = (float)(g_seed.d * hscale + hoffset);
		star.y = (float)(g_seed.b * vscale + voffset);
		star2.x = (float)(g_seed2.d * hscale + hoffset);
		star2.y = (float)(g_seed2.b * vscale + voffset);
		double d = distanceBetweenPlanetPositions(g_seed.d, g_seed.b, g_seed2.d, g_seed2.b);
		
		if (d <= ([player fuelCapacity] / 10.0f))	// another_commander - Default to 7.0 LY.
		{
			glVertex3f(x+star.x, y+star.y, z);
			glVertex3f(x+star2.x, y+star2.y, z);
		}
	}
	OOGLEND();
	
	if (routeInfo)
	{
		int route_hops = [(NSArray *)[routeInfo objectForKey:@"route"] count] -1;
		
		if (optimizeBy == OPTIMIZED_BY_JUMPS)
		{
			OOGL(glColor4f(1.0f, 1.0f, 0.0f, alpha)); // Yellow for plotting routes optimized for distance.
		}
		else
		{
			OOGL(glColor4f(0.0f, 1.0f, 1.0f, alpha)); // Cyan for plotting routes optimized for time.
		}
		int loc;
		for (i = 0; i < route_hops; i++)
		{
			loc = [[routeInfo objectForKey:@"route"] oo_intAtIndex:i];
			
			g_seed = [UNIVERSE systemSeedForSystemNumber:loc];
			g_seed2 = [UNIVERSE systemSeedForSystemNumber:[[routeInfo objectForKey:@"route"] oo_intAtIndex:(i+1)]];
			star.x = (float)(g_seed.d * hscale + hoffset);
			star.y = (float)(g_seed.b * vscale + voffset);
			star2.x = (float)(g_seed2.d * hscale + hoffset);
			star2.y = (float)(g_seed2.b * vscale + voffset);
			
			OOGLBEGIN(GL_LINES);
				glVertex3f(x+star.x, y+star.y, z);
				glVertex3f(x+star2.x, y+star2.y, z);
			OOGLEND();
			
			// Label the route.
			OODrawString([UNIVERSE systemNameIndex:loc], x + star.x + 2.0, y + star.y - 8.0, z, NSMakeSize(8,8));
		}
		// Label the destination, which was not included in the above loop.
		loc = [[routeInfo objectForKey:@"route"] oo_intAtIndex:i];
		OODrawString([UNIVERSE systemNameIndex:loc], x + star2.x + 2.0, y + star2.y - 10.0, z, NSMakeSize(10,10));	
	}
}

@end