/*
	
	OOLegacyTexture.m
	
	Copyright (C) 2007-2011 Jens Ayton and contributors
	
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

#import "OOLegacyTextureInternal.h"
#import "OOLegacyConcreteTexture.h"
#import "OONullTexture.h"

#import "OOLegacyTextureLoader.h"
#import "OOLegacyTextureGenerator.h"

#import "OOUniverse.h"
#import "ResourceManager.h"
#import "OOOpenGLExtensionManager.h"
#import "OOMacroOpenGL.h"
#import "OOCache.h"
#import "OOPixMap.h"


/*	Texture caching:
	two and a half parallel caching mechanisms are used. sLiveTextureCache
	tracks all live texture objects with cache keys, without retaining them
	(using NSValues to refer to the objects).
	
	sAllLiveTextures tracks all textures, including ones without cache keys,
	so that they can be notified of graphics resets. This also uses NSValues
	to avoid retaining the textures.
	
	sRecentTextures tracks up to kRecentTexturesCount textures which
	have been used recently, and retains them.
	
	This means that the number of live texture objects will never fall below
	80% of kRecentTexturesCount (80% comes from the behaviour of OOCache), but
	old textures will eventually be released. If the number of active textures
	exceeds kRecentTexturesCount, all of them will be reusable through
	sLiveTextureCache, but only a most-recently-fetched subset will be kept
	around by the cache when the number drops.
	
	Note the textures in sRecentTextures are a superset of the textures in
	sLiveTextureCache, and the textures in sLiveTextureCache are a superset
	of sRecentTextures.
*/
enum
{
	kRecentTexturesCount		= 50
};

static NSMutableDictionary	*sLiveTextureCache;
static NSMutableSet			*sAllLiveTextures;
static OOCache				*sRecentTextures;


static BOOL					sCheckedExtensions;
OOTextureInfo				gOOTextureInfo;


@interface OOLegacyTexture (OOPrivate)

- (void) addToCaches;
+ (OOLegacyTexture *) existingTextureForKey:(NSString *)key;

- (void) forceRebind;

+ (void)checkExtensions;

#ifndef NDEBUG
- (id) retainInContext:(NSString *)context;
- (void) releaseInContext:(NSString *)context;
- (id) autoreleaseInContext:(NSString *)context;
#endif

@end


#ifndef NDEBUG
static NSString *sGlobalTraceContext = nil;

#define SET_TRACE_CONTEXT(str) do { sGlobalTraceContext = (str); } while (0)
#else
#define SET_TRACE_CONTEXT(str) do { } while (0)
#endif
#define CLEAR_TRACE_CONTEXT() SET_TRACE_CONTEXT(nil)


@implementation OOLegacyTexture

+ (id)textureWithName:(NSString *)name
			 inFolder:(NSString*)directory
			  options:(uint32_t)options
		   anisotropy:(GLfloat)anisotropy
			  lodBias:(GLfloat)lodBias
{
	NSString				*key = nil;
	OOLegacyTexture				*result = nil;
	NSString				*path = nil;
	BOOL					noFNF;
	
	if (EXPECT_NOT(name == nil))  return nil;
	if (EXPECT_NOT(!sCheckedExtensions))  [self checkExtensions];
	
	if (!gOOTextureInfo.anisotropyAvailable || (options & kOOTextureMinFilterMask) != kOOTextureMinFilterMipMap)
	{
		anisotropy = 0.0f;
	}
	if ((options & kOOTextureMinFilterMask) != kOOTextureMinFilterMipMap)
	{
		lodBias = 0.0f;
	}
	
	noFNF = (options & kOOTextureNoFNFMessage) != 0;
	options = OOApplyTetureOptionDefaults(options & ~kOOTextureNoFNFMessage);
	
	// Look for existing texture
	key = [NSString stringWithFormat:@"%@%@%@:0x%.4X/%g/%g", directory ? directory : (NSString *)@"", directory ? @"/" : @"", name, options, anisotropy, lodBias];
	result = [OOLegacyTexture existingTextureForKey:key];
	if (result == nil)
	{
		path = [ResourceManager pathForFileNamed:name inFolder:directory];
		if (path == nil)
		{
			if (!noFNF)  OOLogWARN(kOOLogFileNotFound, @"Could not find texture file \"%@\".", name);
			return nil;
		}
		
		// No existing texture, load texture.
		result = [[[OOLegacyConcreteTexture alloc] initWithPath:path key:key options:options anisotropy:anisotropy lodBias:lodBias] autorelease];
	}
	
	
	return result;
}


+ (id)textureWithName:(NSString *)name
			 inFolder:(NSString*)directory
{
	return [self textureWithName:name
						inFolder:directory
						 options:kOOTextureDefaultOptions
					  anisotropy:kOOTextureDefaultAnisotropy
						 lodBias:kOOTextureDefaultLODBias];
}


+ (id)textureWithConfiguration:(id)configuration
{
	return [self textureWithConfiguration:configuration extraOptions:0];
}


+ (id) textureWithConfiguration:(id)configuration extraOptions:(uint32_t)extraOptions
{
	NSString				*name = nil;
	uint32_t				options = 0;
	GLfloat					anisotropy = 0.0f;
	GLfloat					lodBias = 0.0f;
	
	if (!OOInterpretTextureSpecifier(configuration, &name, &options, &anisotropy, &lodBias))  return nil;
	
	return [self textureWithName:name inFolder:@"Textures" options:options | extraOptions anisotropy:anisotropy lodBias:lodBias];
}


+ (id) nullTexture
{
	return [OONullTexture sharedNullTexture];
}


+ (id) textureWithGenerator:(OOLegacyTextureGenerator *)generator
{
	if (generator == nil)  return nil;
	
#ifndef OOTEXTURE_NO_CACHE
	OOLegacyTexture *existing = [OOLegacyTexture existingTextureForKey:[generator cacheKey]];
	if (existing != nil)  return [[existing retain] autorelease];
#endif
	
	if (![generator enqueue])
	{
		OOLogERR(@"texture.generator.queue.failed", @"Failed to queue generator %@", generator);
		return nil;
	}
	OOLog(@"texture.generator.queue", @"Queued texture generator %@", generator);
	
	OOLegacyTexture *result = [[[OOLegacyConcreteTexture alloc] initWithLoader:generator
															   key:[generator cacheKey]
														   options:OOApplyTetureOptionDefaults([generator textureOptions])
														anisotropy:[generator anisotropy]
														   lodBias:[generator lodBias]] autorelease];
	
	return result;
}


- (id) init
{
	if ((self = [super init]))
	{
		if (EXPECT_NOT(sAllLiveTextures == nil))  sAllLiveTextures = [[NSMutableSet alloc] init];
		[sAllLiveTextures addObject:[NSValue valueWithPointer:self]];
	}
	
	return self;
}


- (void) dealloc
{
	[sAllLiveTextures removeObject:[NSValue valueWithPointer:self]];
	
	[super dealloc];
}


- (void)apply
{
	OOLogGenericSubclassResponsibility();
}


+ (void)applyNone
{
	OO_ENTER_OPENGL();
	OOGL(glBindTexture(GL_TEXTURE_2D, 0));
	OOGL(glBindTexture(GL_TEXTURE_CUBE_MAP, 0));
	OOGL(glTexEnvf(GL_TEXTURE_FILTER_CONTROL, GL_TEXTURE_LOD_BIAS, 0));
}


- (void)ensureFinishedLoading
{
}


- (BOOL) isFinishedLoading
{
	return YES;
}


- (NSString *) cacheKey
{
	return nil;
}


- (NSSize) dimensions
{
	OOLogGenericSubclassResponsibility();
	return NSZeroSize;
}


- (NSSize) originalDimensions
{
	return [self dimensions];
}


- (BOOL) isMipMapped
{
	OOLogGenericSubclassResponsibility();
	return NO;
}


- (struct OOPixMap) copyPixMapRepresentation
{
	return kOONullPixMap;
}


- (BOOL) isRectangleTexture
{
	return NO;
}


- (BOOL) isCubeMap
{
	return NO;
}


- (NSSize)texCoordsScale
{
	return NSMakeSize(1.0f, 1.0f);
}


- (GLint)glTextureName
{
	OOLogGenericSubclassResponsibility();
	return 0;
}


+ (void)clearCache
{
	/*	Does not clear sAllLiveTextures - that really must refer to all
		live texture objects.
	*/
	SET_TRACE_CONTEXT(@"clearing sLiveTextureCache");
	[sLiveTextureCache autorelease];
	sLiveTextureCache = nil;
	
	SET_TRACE_CONTEXT(@"clearing sRecentTextures");
	[sRecentTextures autorelease];
	sRecentTextures = nil;
	CLEAR_TRACE_CONTEXT();
}


+ (void)rebindAllTextures
{
	NSEnumerator			*textureEnum = nil;
	id						texture = nil;
	
	// Keeping around unused, cached textures is unhelpful at this point.
	DESTROY(sRecentTextures);
	
	for (textureEnum = [sAllLiveTextures objectEnumerator]; (texture = [[textureEnum nextObject] pointerValue]); )
	{
		[texture forceRebind];
	}
}


#ifndef NDEBUG
- (void) setTrace:(BOOL)trace
{
	if (trace && !_trace)
	{
		OOLog(@"texture.allocTrace.begin", @"Started tracing texture %p with retain count %u.", self, [self retainCount]);
	}
	_trace = trace;
}


+ (NSArray *) cachedTexturesByAge
{
	return [sRecentTextures objectsByAge];
}


+ (NSSet *) allTextures
{
	NSMutableSet *result = [NSMutableSet setWithCapacity:[sAllLiveTextures count]];
	NSValue *box = nil;
	NSEnumerator *texEnum = nil;
	for (texEnum = [sAllLiveTextures objectEnumerator]; (box = [texEnum nextObject]); )
	{
		[result addObject:[box pointerValue]];
	}
	
	return result;
}


- (size_t) dataSize
{
	NSSize dimensions = [self dimensions];
	size_t size = dimensions.width * dimensions.height;
	if ([self isCubeMap])  size *= 6;
	if ([self isMipMapped])  size = size * 4 / 3;
	
	return size;
}


- (NSString *) name
{
	OOLogGenericSubclassResponsibility();
	return nil;
}
#endif


- (void) forceRebind
{
	OOLogGenericSubclassResponsibility();
}


- (void) addToCaches
{
#ifndef OOTEXTURE_NO_CACHE
	NSString *cacheKey = [self cacheKey];
	if (cacheKey == nil)  return;
	
	// Add self to in-use textures cache, wrapped in an NSValue so the texture isn't retained by the cache.
	if (EXPECT_NOT(sLiveTextureCache == nil))  sLiveTextureCache = [[NSMutableDictionary alloc] init];
	
	SET_TRACE_CONTEXT(@"in-use textures cache - SHOULD NOT RETAIN");
	[sLiveTextureCache setObject:[NSValue valueWithPointer:self] forKey:cacheKey];
	CLEAR_TRACE_CONTEXT();
	
	// Add self to recent textures cache.
	if (EXPECT_NOT(sRecentTextures == nil))
	{
		sRecentTextures = [[OOCache alloc] init];
		[sRecentTextures setName:@"recent textures"];
		[sRecentTextures setAutoPrune:YES];
		[sRecentTextures setPruneThreshold:kRecentTexturesCount];
	}
	
	SET_TRACE_CONTEXT(@"adding to recent textures cache");
	[sRecentTextures setObject:self forKey:cacheKey];
	CLEAR_TRACE_CONTEXT();
#endif
}


- (void) removeFromCaches
{
#ifndef OOTEXTURE_NO_CACHE
	NSString *cacheKey = [self cacheKey];
	if (cacheKey == nil)  return;
	
	[sLiveTextureCache removeObjectForKey:cacheKey];
	NSAssert([sRecentTextures objectForKey:cacheKey] != self, @"Texture retain count error."); //miscount in autorelease
	// The following line is needed in order to avoid crashes when there's a 'texture retain count error'. Please do not delete. -- Kaks 20091221
	[sRecentTextures removeObjectForKey:cacheKey]; // make sure there's no reference left inside sRecentTexture ( was a show stopper for 1.73)
#endif
}


+ (OOLegacyTexture *) existingTextureForKey:(NSString *)key
{
#ifndef OOTEXTURE_NO_CACHE
	if (key != nil)
	{
		return (OOLegacyTexture *)[[sLiveTextureCache objectForKey:key] pointerValue];
	}
	return nil;
#else
	return nil;
#endif
}


+ (void)checkExtensions
{
	OO_ENTER_OPENGL();
	
	sCheckedExtensions = YES;
	
	OOOpenGLExtensionManager	*extMgr = [OOOpenGLExtensionManager sharedManager];
	
#if GL_EXT_texture_filter_anisotropic
	gOOTextureInfo.anisotropyAvailable = [extMgr haveExtension:@"GL_EXT_texture_filter_anisotropic"];
	OOGL(glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &gOOTextureInfo.anisotropyScale));
	gOOTextureInfo.anisotropyScale *= OOClamp_0_1_f([[NSUserDefaults standardUserDefaults] oo_floatForKey:@"texture-anisotropy-scale" defaultValue:0.5]);
#endif
	
#if OO_GL_CLIENT_STORAGE
	gOOTextureInfo.clientStorageAvailable = [extMgr haveExtension:@"GL_APPLE_client_storage"];
#endif
	
#if GL_EXT_texture_rectangle
	gOOTextureInfo.rectangleTextureAvailable = [extMgr haveExtension:@"GL_EXT_texture_rectangle"];
#endif
}


#ifndef NDEBUG
- (id) retainInContext:(NSString *)context
{
	if (_trace)
	{
		if (context)  OOLog(@"texture.allocTrace.retain", @"Texture %p retained (retain count -> %u) - %@.", self, [self retainCount] + 1, context);
		else  OOLog(@"texture.allocTrace.retain", @"Texture %p retained.", self, [self retainCount] + 1);
	}
	
	return [super retain];
}


- (void) releaseInContext:(NSString *)context
{
	if (_trace)
	{
		if (context)  OOLog(@"texture.allocTrace.release", @"Texture %p released (retain count -> %u) - %@.", self, [self retainCount] - 1, context);
		else  OOLog(@"texture.allocTrace.release", @"Texture %p released (retain count -> %u).", self, [self retainCount] - 1);
	}
	
	[super release];
}


- (id) autoreleaseInContext:(NSString *)context
{
	if (_trace)
	{
		if (context)  OOLog(@"texture.allocTrace.autoreleased", @"Texture %p autoreleased - %@.", self, context);
		else  OOLog(@"texture.allocTrace.autoreleased", @"Texture %p autoreleased.", self);
	}
	
	return [super autorelease];
}


- (id) retain
{
	return [self retainInContext:sGlobalTraceContext];
}


- (oneway void) release
{
	[self releaseInContext:sGlobalTraceContext];
}


- (id) autorelease
{
	return [self autoreleaseInContext:sGlobalTraceContext];
}
#endif

@end


@implementation NSDictionary (OOTextureConveniences)

- (NSDictionary *) oo_textureSpecifierForKey:(id)key defaultName:(NSString *)name
{
	return OOTextureSpecFromObject([self objectForKey:key], name);
}

@end

@implementation NSArray (OOTextureConveniences)

- (NSDictionary *) oo_textureSpecifierAtIndex:(unsigned)index defaultName:(NSString *)name
{
	return OOTextureSpecFromObject([self objectAtIndex:index], name);
}

@end

NSDictionary *OOTextureSpecFromObject(id object, NSString *defaultName)
{
	if (object == nil)  object = defaultName;
	if ([object isKindOfClass:[NSString class]])
	{
		if ([object isEqualToString:@""])  return nil;
		return [NSDictionary dictionaryWithObject:object forKey:@"name"];
	}
	if (![object isKindOfClass:[NSDictionary class]])  return nil;
	
	// If we're here, it's a dictionary.
	if (defaultName == nil || [object oo_stringForKey:@"name"] != nil)  return object;
	
	// If we get here, there's no "name" key and there is a default, so we fill it in:
	NSMutableDictionary *mutableResult = [NSMutableDictionary dictionaryWithDictionary:object];
	[mutableResult setObject:[[defaultName copy] autorelease] forKey:@"name"];
	return mutableResult;
}


uint8_t OOTextureComponentsForFormat(OOTextureDataFormat format)
{
	switch (format)
	{
		case kOOTextureDataRGBA:
			return 4;
			
		case kOOTextureDataGrayscale:
			return 1;
			
		case kOOTextureDataGrayscaleAlpha:
			return 2;
			
		case kOOTextureDataInvalid:
			break;
	}
	
	return 0;
}


BOOL OOInterpretTextureSpecifier(id specifier, NSString **outName, uint32_t *outOptions, float *outAnisotropy, float *outLODBias)
{
	NSString			*name = nil;
	uint32_t			options = kOOTextureDefaultOptions;
	float				anisotropy = kOOTextureDefaultAnisotropy;
	float				lodBias = kOOTextureDefaultLODBias;
	
	if ([specifier isKindOfClass:[NSString class]])
	{
		name = specifier;
	}
	else if ([specifier isKindOfClass:[NSDictionary class]])
	{
		name = [specifier oo_stringForKey:@"name"];
		if (name == nil)
		{
			OOLog(@"texture.load.noName", @"Invalid texture configuration dictionary (must specify name):\n%@", specifier);
			return NO;
		}
		
		NSString *filterString = [specifier oo_stringForKey:@"min_filter" defaultValue:@"default"];
		if ([filterString isEqualToString:@"nearest"])  options |= kOOTextureMinFilterNearest;
		else if ([filterString isEqualToString:@"linear"])  options |= kOOTextureMinFilterLinear;
		else if ([filterString isEqualToString:@"mipmap"])  options |= kOOTextureMinFilterMipMap;
		else  options |= kOOTextureMinFilterDefault;	// Covers "default"
		
		filterString = [specifier oo_stringForKey:@"mag_filter" defaultValue:@"default"];
		if ([filterString isEqualToString:@"nearest"])  options |= kOOTextureMagFilterNearest;
		else  options |= kOOTextureMagFilterLinear;	// Covers "default" and "linear"
		
		if ([specifier oo_boolForKey:@"no_shrink" defaultValue:NO])  options |= kOOTextureNoShrink;
		if ([specifier oo_boolForKey:@"repeat_s" defaultValue:NO])  options |= kOOTextureRepeatS;
		if ([specifier oo_boolForKey:@"repeat_t" defaultValue:NO])  options |= kOOTextureRepeatT;
		if ([specifier oo_boolForKey:@"cube_map" defaultValue:NO])  options |= kOOTextureAllowCubeMap;
		anisotropy = [specifier oo_floatForKey:@"anisotropy" defaultValue:kOOTextureDefaultAnisotropy];
		lodBias = [specifier oo_floatForKey:@"texture_LOD_bias" defaultValue:kOOTextureDefaultLODBias];
		
		NSString *extractChannel = [specifier oo_stringForKey:@"extract_channel"];
		if (extractChannel != nil)
		{
			if ([extractChannel isEqualToString:@"r"])  options |= kOOTextureExtractChannelR;
			else if ([extractChannel isEqualToString:@"g"])  options |= kOOTextureExtractChannelG;
			else if ([extractChannel isEqualToString:@"b"])  options |= kOOTextureExtractChannelB;
			else if ([extractChannel isEqualToString:@"a"])  options |= kOOTextureExtractChannelA;
			else
			{
				OOLogWARN(@"texture.load.extractChannel.invalid", @"Unknown value \"%@\" for extract_channel (should be \"r\", \"g\", \"b\" or \"a\").", extractChannel);
			}
		}
	}
	else
	{
		// Bad type
		if (specifier != nil)  OOLog(kOOLogParameterError, @"%s: expected string or dictionary, got %@.", __PRETTY_FUNCTION__, [specifier class]);
		return NO;
	}
	
	if ([name length] == 0)  return NO;
	
	if (outName != NULL)  *outName = name;
	if (outOptions != NULL)  *outOptions = options;
	if (outAnisotropy != NULL)  *outAnisotropy = anisotropy;
	if (outLODBias != NULL)  *outLODBias = lodBias;
	
	return YES;
}


uint32_t OOApplyTetureOptionDefaults(uint32_t options)
{
	// Set default flags if needed
	if ((options & kOOTextureMinFilterMask) == kOOTextureMinFilterDefault)
	{
		if ([UNIVERSE reducedDetail])
		{
			options |= kOOTextureMinFilterLinear;
		}
		else
		{
			options |= kOOTextureMinFilterMipMap;
		}
	}
	
	if (options & kOOTextureAllowRectTexture)
	{
		// Apply rectangle texture restrictions (regardless of whether rectangle textures are available, for consistency)
		options &= kOOTextureFlagsAllowedForRectangleTexture;
		if ((options & kOOTextureMinFilterMask) == kOOTextureMinFilterMipMap)
		{
			options = (kOOTextureMinFilterMask & ~kOOTextureMinFilterMask) | kOOTextureMinFilterLinear;
		}
		
#if GL_EXT_texture_rectangle
		if (!gOOTextureInfo.rectangleTextureAvailable)
		{
			options &= ~kOOTextureAllowRectTexture;
		}
#else
		options &= ~kOOTextureAllowRectTexture;
#endif
	}
	
	options &= kOOTextureDefinedFlags;
	
	return options;
}
