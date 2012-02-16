/*

OODefaultShaderSynthesizer.m


Copyright © 2011 Jens Ayton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

#import "OODefaultShaderSynthesizer.h"
#import "OORenderMesh.h"
#import	"OOMaterialSpecification.h"
#import "OOTextureSpecification.h"
#import "OOAbstractVertex.h"


typedef enum
{
	kLightingUndetermined,
	kLightingUniform,			// No normals can be determined
	kLightingNormalOnly,		// No tangents, so no normal mapping possible
	kLightingNormalTangent,		// Normal and tangent defined, bitangent determined by cross product
	kLightingTangentBitangent	// Tangent and bitangent defined, normal determined by cross product
} LightingMode;


@interface OODefaultShaderSynthesizer: NSObject
{
@private
	OOMaterialSpecification		*_spec;
	OORenderMesh				*_mesh;
	id <OOProblemReporting>		_problemReporter;
	
	NSString					*_vertexShader;
	NSString					*_fragmentShader;
	NSMutableArray				*_textures;
	NSMutableDictionary			*_uniforms;
	
	NSMutableString				*_attributes;
	NSMutableString				*_varyings;
	NSMutableString				*_vertexUniforms;
	NSMutableString				*_fragmentUniforms;
	NSMutableString				*_vertexHelpers;
	NSMutableString				*_fragmentHelpers;
	NSMutableString				*_vertexBody;
	NSMutableString				*_fragmentPreTextures;
	NSMutableString				*_fragmentTextureLookups;
	NSMutableString				*_fragmentBody;
	
	// _texturesByName: dictionary mapping texture file names to texture specifications.
	NSMutableDictionary			*_texturesByName;
	// _textureIDs: dictionary mapping texture file names to numerical IDs used to name variables.
	NSMutableDictionary			*_textureIDs;
	// _sampledTextures: hash of integer texture IDs for which we’ve set up a sample.
	NSHashTable					*_sampledTextures;
	
	LightingMode				_lightingMode;
	uint8_t						_normalAttrSize;
	uint8_t						_tangentAttrSize;
	uint8_t						_bitangentAttrSize;
	
	NSUInteger					_usesNormalMap: 1,
								_usesDiffuseTerm: 1,
								_constZNormal: 1,
	
	// Completion flags for various generation stages.
								_completed_writeFinalColorComposite: 1,
								_completed_writeDiffuseColorTerm: 1,
								_completed_writeSpecularLighting: 1,
								_completed_writeLightMaps: 1,
								_completed_writeDiffuseLighting: 1,
								_completed_writeDiffuseColorTermIfNeeded: 1,
								_completed_writeVertexPosition: 1,
								_completed_writeNormalIfNeeded: 1,
								_completed_writeNormal: 1,
								_completed_writeLightVector: 1,
								_completed_writeEyeVector: 1, 
								_completed_writeTotalColor: 1,
								_completed_writeTextureCoordRead: 1,
								_completed_writeVertexTangentBasis: 1;
	
#ifndef NDEBUG
	NSHashTable					*_stagesInProgress;
#endif
}

- (id) initWithMaterialSpecifiction:(OOMaterialSpecification *)spec
							   mesh:(OORenderMesh *)mesh
					problemReporter:(id <OOProblemReporting>) problemReporter;

- (BOOL) run;

- (NSString *) vertexShader;
- (NSString *) fragmentShader;
- (NSArray *) textureSpecifications;
- (NSDictionary *) uniformSpecifications;

- (void) createTemporaries;
- (void) destroyTemporaries;

- (void) composeVertexShader;
- (void) composeFragmentShader;

- (LightingMode) lightingMode;
- (BOOL) tangentSpaceLighting;


/*	Stages. These should only be called through the REQUIRE_STAGE macro to
	avoid duplicated code and ensure data depedencies are met.
*/

/*	writeFinalColorComposite
	This stage writes the final fragment shader. It also pulls in other stages
	through dependencies.
*/
- (void) writeFinalColorComposite;

/*	writeDiffuseColorTermIfNeeded
	Generates and populates the fragment shader value vec3 diffuseColor, unless
	the diffuse term is black. If a diffuseColor is generated, _usesDiffuseTerm
	is set. The value will be const if possible.
	See also: writeDiffuseColorTerm.
*/
- (void) writeDiffuseColorTermIfNeeded;

/*	writeDiffuseColorTerm
	Generates vec3 diffuseColor unconditionally – that is, even if the diffuse
	term is black.
	See also: writeDiffuseColorTermIfNeeded.
*/
- (void) writeDiffuseColorTerm;

/*	writeVertexTangentBasis
	Generates tangent space basis matrix (TBN) in vertex shader, if in tangent-
	space lighting mode. If not, an exeception is raised.
*/
- (void) writeVertexTangentBasis;

/*	writeNormalIfNeeded
	Writes fragment variable vec3 normal if necessary. Otherwise, it sets
	_constZNormal, indicating that the normal is always (0, 0, 1).
	
	See also: writeNormal.
*/
- (void) writeNormalIfNeeded;

/*	writeNormal
	Generates vec3 normal unconditionally – if _constZNormal is set, normal will
	be const vec3 normal = vec3 (0.0, 0.0, 1.0).
*/
- (void) writeNormal;

/*	writeLightVector
	Generate the fragment variable vec3 lightVector (unit vector) for temporary
	lighting. Calling this if lighting mode is kLightingUniform will cause an
	exception.
*/
- (void) writeLightVector;

/*	writeTotalColor
	Generate vec3 totalColor, the accumulator for output colour values.
*/
- (void) writeTotalColor;


#ifndef NDEBUG
#define REQUIRE_STAGE(NAME) if (!_completed_##NAME) { [self performStage:@selector(NAME)]; _completed_##NAME = YES; }
- (void) performStage:(SEL)stage;
#else
#define REQUIRE_STAGE(NAME) if (!_completed_##NAME) { [self NAME]; _completed_##NAME = YES; }
#endif

@end


BOOL OOSynthesizeMaterialShader(OOMaterialSpecification *materialSpec, OORenderMesh *mesh, NSString **outVertexShader, NSString **outFragmentShader, NSArray **outTextureSpecs, NSDictionary **outUniformSpecs, id <OOProblemReporting> problemReporter)
{
	NSCParameterAssert(materialSpec != nil && outVertexShader != NULL && outFragmentShader != NULL && outTextureSpecs != NULL && outUniformSpecs != NULL);
	
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
	
	OODefaultShaderSynthesizer *synthesizer = [[OODefaultShaderSynthesizer alloc]
											   initWithMaterialSpecifiction:materialSpec
											   mesh:mesh
											   problemReporter:problemReporter];
	[synthesizer autorelease];
	
	BOOL OK = [synthesizer run];
	if (OK)
	{
		*outVertexShader = [[synthesizer vertexShader] retain];
		*outFragmentShader = [[synthesizer fragmentShader] retain];
		*outTextureSpecs = [[synthesizer textureSpecifications] retain];
		*outUniformSpecs = [[synthesizer uniformSpecifications] retain];
	}
	else
	{
		*outVertexShader = nil;
		*outFragmentShader = nil;
		*outTextureSpecs = nil;
		*outUniformSpecs = nil;
	}
	[pool release];
	
	[*outVertexShader autorelease];
	[*outFragmentShader autorelease];
	[*outTextureSpecs autorelease];
	[*outUniformSpecs autorelease];
	
	return YES;
}


@implementation OODefaultShaderSynthesizer

- (id) initWithMaterialSpecifiction:(OOMaterialSpecification *)spec
							   mesh:(OORenderMesh *)mesh
					problemReporter:(id <OOProblemReporting>) problemReporter
{
	if ((self = [super init]))
	{
		_spec = [spec retain];
		_mesh = [mesh retain];
		_problemReporter = [problemReporter retain];
	}
	
	return self;
}


- (void) dealloc
{
	[self destroyTemporaries];
	DESTROY(_spec);
	DESTROY(_mesh);
	DESTROY(_problemReporter);
	DESTROY(_vertexShader);
	DESTROY(_fragmentShader);
	DESTROY(_textures);
	
    [super dealloc];
}


- (NSString *) vertexShader
{
	return _vertexShader;
}


- (NSString *) fragmentShader
{
	return _fragmentShader;
}


- (NSArray *) textureSpecifications
{
#ifndef NDEBUG
	return [NSArray arrayWithArray:_textures];
#else
	return _textures;
#endif
}


- (NSDictionary *) uniformSpecifications
{
#ifndef NDEBUG
	return [NSDictionary dictionaryWithDictionary:_uniforms];
#else
	return _uniforms;
#endif
}


- (BOOL) run
{
	[self createTemporaries];
	_uniforms = [[NSMutableDictionary alloc] init];
	[_vertexBody appendString:@"void main(void)\n{\n"];
	[_fragmentPreTextures appendString:@"void main(void)\n{\n"];
	
	@try
	{
		REQUIRE_STAGE(writeFinalColorComposite);
		
		[self composeVertexShader];
		[self composeFragmentShader];
	}
	@catch (NSException *exception)
	{
		// Error should have been reported already.
		return NO;
	}
	@finally
	{
		[self destroyTemporaries];
	}
	
	return YES;
}


// MARK: - Utilities

static void AppendIfNotEmpty(NSMutableString *buffer, NSString *segment, NSString *name)
{
	if ([segment length] > 0)
	{
		if ([buffer length] > 0)  [buffer appendString:@"\n\n"];
		if ([name length] > 0)  [buffer appendFormat:@"// %@\n", name];
		[buffer appendString:segment];
	}
}


- (void) appendVariable:(NSString *)name ofType:(NSString *)type withPrefix:(NSString *)prefix to:(NSMutableString *)buffer
{
	NSUInteger typeDeclLength = [prefix length] + [type length] + 1;
	NSUInteger padding = (typeDeclLength < 20) ? (23 - typeDeclLength) / 4 : 1;
	[buffer appendFormat:@"%@ %@%@%@;\n", prefix, type, OOTabString(padding), name];
}


- (void) addAttribute:(NSString *)name ofType:(NSString *)type
{
	[self appendVariable:name ofType:type withPrefix:@"attribute" to:_attributes];
}


- (void) addVarying:(NSString *)name ofType:(NSString *)type
{
	[self appendVariable:name ofType:type withPrefix:@"varying" to:_varyings];
}


- (void) addVertexUniform:(NSString *)name ofType:(NSString *)type
{
	[self appendVariable:name ofType:type withPrefix:@"uniform" to:_vertexUniforms];
}


- (void) addFragmentUniform:(NSString *)name ofType:(NSString *)type
{
	[self appendVariable:name ofType:type withPrefix:@"uniform" to:_fragmentUniforms];
}


- (LightingMode) lightingMode
{
	if (_lightingMode == kLightingUndetermined)
	{
		_normalAttrSize = [_mesh attributeSizeForKey:kOONormalAttributeKey];
		_tangentAttrSize = [_mesh attributeSizeForKey:kOOTangentAttributeKey];
		_bitangentAttrSize = [_mesh attributeSizeForKey:kOOBitangentAttributeKey];
		
		if (_tangentAttrSize >= 3)
		{
			if (_bitangentAttrSize >= 3)
			{
				_lightingMode = kLightingTangentBitangent;
			}
			else if (_normalAttrSize >= 3)
			{
				_lightingMode = kLightingNormalTangent;
			}
		}
		else
		{
			if (_normalAttrSize >= 3)
			{
				_lightingMode = kLightingNormalOnly;
			}
		}
		
		if (_lightingMode == kLightingUndetermined)
		{
			_lightingMode = kLightingUniform;
			OOReportWarning(_problemReporter, @"Mesh \"%@\" does not provide normals or tangents and bitangents, so no lighting is possible.", [_mesh name]);
		}
	}
	return _lightingMode;
}


- (BOOL) tangentSpaceLighting
{
	LightingMode mode = [self lightingMode];
	return mode == kLightingTangentBitangent || mode == kLightingNormalTangent;
}


- (void) composeVertexShader
{
	while ([_vertexBody hasSuffix:@"\t\n"])
	{
		[_vertexBody deleteCharactersInRange:(NSRange){ [_vertexBody length] - 2, 2 }];
	}
	[_vertexBody appendString:@"}"];
	
	NSMutableString *vertexShader = [NSMutableString string];
	AppendIfNotEmpty(vertexShader, _attributes, @"Attributes");
	AppendIfNotEmpty(vertexShader, _vertexUniforms, @"Uniforms");
	AppendIfNotEmpty(vertexShader, _varyings, @"Varyings");
	AppendIfNotEmpty(vertexShader, _vertexHelpers, @"Helper functions");
	AppendIfNotEmpty(vertexShader, _vertexBody, nil);
	
#ifndef NDEBUG
	_vertexShader = [vertexShader copy];
#else
	_vertexShader = [vertexShader retain];
#endif
}


- (void) composeFragmentShader
{
	while ([_fragmentBody hasSuffix:@"\t\n"])
	{
		[_fragmentBody deleteCharactersInRange:(NSRange){ [_fragmentBody length] - 2, 2 }];
	}
	
	NSMutableString *fragmentShader = [NSMutableString string];
	AppendIfNotEmpty(fragmentShader, _fragmentUniforms, @"Uniforms");
	AppendIfNotEmpty(fragmentShader, _varyings, @"Varyings");
	AppendIfNotEmpty(fragmentShader, _fragmentHelpers, @"Helper functions");
	AppendIfNotEmpty(fragmentShader, _fragmentPreTextures, nil);
	if ([_fragmentTextureLookups length] > 0)
	{
		[fragmentShader appendString:@"\t\n\t// Texture lookups\n"];
		[fragmentShader appendString:_fragmentTextureLookups];
	}
	[fragmentShader appendString:@"\t\n"];
	[fragmentShader appendString:_fragmentBody];
	[fragmentShader appendString:@"}"];
	
#ifndef NDEBUG
	_fragmentShader = [fragmentShader copy];
#else
	_fragmentShader = [fragmentShader retain];
#endif
}


- (NSUInteger) assignIDForTexture:(OOTextureSpecification *)spec
{
	NSParameterAssert(spec != nil);
	
	if ([spec isCubeMap])
	{
		OOReportError(_problemReporter, @"The material \"%@\" of \"%@\" specifies a cube map texture, but doesn't have custom shaders. Cube map textures are not supported with the default shaders.", [_spec materialKey], [_mesh name]);
		[NSException raise:NSGenericException format:@"Invalid material"];
	}
	
	NSUInteger texID;
	NSString *name = [spec textureMapName];
	OOTextureSpecification *existing = [_texturesByName objectForKey:name];
	if (existing == nil)
	{
		texID = [_texturesByName count];
		NSNumber	*texIDObj = $int(texID);
		NSString	*texUniform = $sprintf(@"uTexture%u", texID);
		
		[_textures addObject:spec];
		[_texturesByName setObject:spec forKey:name];
		[_textureIDs setObject:texIDObj forKey:name];
		[_uniforms setObject:$dict(@"type", @"texture", @"value", texIDObj) forKey:texUniform];
		
		[self addFragmentUniform:texUniform ofType:@"sampler2D"];
	}
	else
	{
		if (![spec isEqual:existing])
		{
			OOReportWarning(_problemReporter, @"The texture map \"%@\" is used more than once in material \"%@\" of \"%@\", and the options specified are not consistent. Only one set of options will be used.", name, [_spec materialKey], [_mesh name]);
		}
		texID = [_textureIDs oo_unsignedIntegerForKey:name];
	}
	return texID;
}


- (void) setUpOneTexture:(OOTextureSpecification *)spec
{
	if (spec == nil)  return;
	
	REQUIRE_STAGE(writeTextureCoordRead);
	
	NSUInteger texID = [self assignIDForTexture:spec];
	if ((NSUInteger)NSHashGet(_sampledTextures, (const void *)(texID + 1)) == 0)
	{
		NSHashInsertKnownAbsent(_sampledTextures, (const void *)(texID + 1));
		[_fragmentTextureLookups appendFormat:@"\tvec4 tex%uSample = texture2D(uTexture%u, texCoords);  // %@\n", texID, texID, [spec textureMapName]];
	}
}


- (void) getSampleName:(NSString **)outSampleName andSwizzleOp:(NSString **)outSwizzleOp forTextureSpec:(OOTextureSpecification *)spec
{
	NSParameterAssert(outSampleName != NULL && outSwizzleOp != NULL && spec != nil);
	
	[self setUpOneTexture:spec];
	
	NSString	*key = [spec textureMapName];
	NSUInteger	texID = [_textureIDs oo_unsignedIntegerForKey:key];
	
	*outSampleName = $sprintf(@"tex%uSample", texID);
	*outSwizzleOp = [spec extractMode];
}


// Generate a read for an RGB value, or a single channel splatted across RGB.
- (NSString *) readRGBForTextureSpec:(OOTextureSpecification *)textureSpec mapName:(NSString *)mapName
{
	NSString *sample, *swizzle;
	[self getSampleName:&sample andSwizzleOp:&swizzle forTextureSpec:textureSpec];
	
	if (swizzle == nil)
	{
		return [sample stringByAppendingString:@".rgb"];
	}
	
	NSUInteger channelCount = [swizzle length];
	
	if (channelCount == 1)
	{
		return $sprintf(@"%@.%@%@%@", sample, swizzle, swizzle, swizzle);
	}
	else if (channelCount == 3)
	{
		return $sprintf(@"%@.%@", sample, swizzle);
	}
	
	OOReportWarning(_problemReporter, @"The %@ map for material \"%@\" of \"%@\" specifies %u channels to extract, but only %@ may be used.", mapName, [_spec materialKey], [_mesh name], channelCount, @"1 or 3");
	return nil;
}


// Generate a read for a single channel.
- (NSString *) readOneChannelForTextureSpec:(OOTextureSpecification *)textureSpec mapName:(NSString *)mapName
{
	NSString *sample, *swizzle;
	[self getSampleName:&sample andSwizzleOp:&swizzle forTextureSpec:textureSpec];
	
	if (swizzle == nil)
	{
		return [sample stringByAppendingString:@".r"];
	}
	
	NSUInteger channelCount = [swizzle length];
	
	if (channelCount == 1)
	{
		return $sprintf(@"%@.%@", sample, swizzle);
	}
	
	OOReportWarning(_problemReporter, @"The %@ map for material \"%@\" of \"%@\" specifies %u channels to extract, but only %@ may be used.", mapName, [_spec materialKey], [_mesh name], channelCount, @"1");
	return nil;
}


#ifndef NDEBUG
- (void) performStage:(SEL)stage
{
	// Ensure that we aren’t recursing.
	if (NSHashGet(_stagesInProgress, stage) != NULL)
	{
		OOReportError(_problemReporter, @"Shader synthesis recursion for stage %@.", NSStringFromSelector(stage));
		[NSException raise:NSInternalInconsistencyException format:@"stage recursion"];
	}
	
	NSHashInsertKnownAbsent(_stagesInProgress, stage);
	
	[self performSelector:stage];
	
	NSHashRemove(_stagesInProgress, stage);
}
#endif


- (void) createTemporaries
{
	_attributes = [NSMutableString string];
	_varyings = [NSMutableString string];
	_vertexUniforms = [NSMutableString string];
	_fragmentUniforms = [NSMutableString string];
	_vertexBody = [NSMutableString string];
	_fragmentPreTextures = [NSMutableString string];
	_fragmentTextureLookups = [NSMutableString string];
	_fragmentBody = [NSMutableString string];
	
	_textures = [[NSMutableArray alloc] init];
	_texturesByName = [[NSMutableDictionary alloc] init];
	_textureIDs = [[NSMutableDictionary alloc] init];
	_sampledTextures = NSCreateHashTable(NSIntegerHashCallBacks, 0);
	
#ifndef NDEBUG
	_stagesInProgress = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 0);
#endif
}


- (void) destroyTemporaries
{
	DESTROY(_attributes);
	DESTROY(_varyings);
	DESTROY(_vertexUniforms);
	DESTROY(_fragmentUniforms);
	DESTROY(_vertexHelpers);
	DESTROY(_fragmentHelpers);
	DESTROY(_vertexBody);
	DESTROY(_fragmentPreTextures);
	DESTROY(_fragmentTextureLookups);
	DESTROY(_fragmentBody);
	
	DESTROY(_texturesByName);
	DESTROY(_textureIDs);
	NSFreeHashTable(_sampledTextures);
	
#ifndef NDEBUG
	DESTROY(_stagesInProgress);
#endif
}


// MARK: - Synthesis stages

- (void) writeTextureCoordRead
{
	// Ensure we have valid texture coordinates.
	NSUInteger texCoordsSize = [_mesh attributeSizeForKey:kOOTexCoordsAttributeKey];
	switch (texCoordsSize)
	{
		case 0:
			OOReportError(_problemReporter, @"The material \"%@\" of \"%@\" uses textures, but the mesh has no %@ attribute.", [_spec materialKey], [_mesh name], kOOTexCoordsAttributeKey);
			[NSException raise:NSGenericException format:@"Invalid material"];
			
		case 1:
			OOReportError(_problemReporter, @"The material \"%@\" of \"%@\" uses textures, but the %@ attribute in the mesh is only one-dimensional.", [_spec materialKey], [_mesh name], kOOTexCoordsAttributeKey);
			[NSException raise:NSGenericException format:@"Invalid material"];
			
		case 2:
			break;	// Perfect!
			
		default:
			OOReportWarning(_problemReporter, @"The mesh \"%@\" has a %@ attribute with %u values per vertex. Only the first two will be used by standard materials.", [_mesh name], kOOTexCoordsAttributeKey, texCoordsSize);
	}
	
	[self addAttribute:@"aTexCoords" ofType:@"vec2"];
	[self addVarying:@"vTexCoords" ofType:@"vec2"];
	[_vertexBody appendString:@"\tvTexCoords = aTexCoords;\n\t\n"];
	
	BOOL haveTexCoords = NO;
	OOTextureSpecification *parallaxMap = [_spec parallaxMap];
	if (parallaxMap != nil)
	{
		float parallaxScale = [_spec parallaxScale];
		if (parallaxScale != 0.0f)
		{
			/*
				We can’t call -getSampleName:... here because the standard
				texture loading mechanism has to occur after determining
				texture coordinates (duh).
			*/
			NSString *swizzle = [parallaxMap extractMode] ?: @"a";
			NSUInteger channelCount = [swizzle length];
			if (channelCount == 1)
			{
				haveTexCoords = YES;
				
				REQUIRE_STAGE(writeEyeVector);
				
				[_fragmentPreTextures appendString:@"\t// Parallax mapping\n"];
				
				NSUInteger texID = [self assignIDForTexture:parallaxMap];
				[_fragmentPreTextures appendFormat:@"\tfloat parallax = texture2D(uTexture%u, vTexCoords).%@;\n", texID, swizzle];
				
				if (parallaxScale != 1.0f)
				{
					[_fragmentPreTextures appendFormat:@"\tparallax *= %g;\n  // Parallax scale", parallaxScale];
				}
				
				float parallaxBias = [_spec parallaxBias];
				if (parallaxBias != 0.0)
				{
					[_fragmentPreTextures appendFormat:@"\tparallax += %g;\n  // Parallax bias", parallaxBias];
				}
				
				[_fragmentPreTextures appendString:@"\tvec2 texCoords = vTexCoords - parallax * eyeVector.xy * vec2(-1.0, 1.0);\n"];
			}
			else
			{
				OOReportWarning(_problemReporter, @"The %@ map for material \"%@\" of \"%@\" specifies %u channels to extract, but only %@ may be used.", @"parallax", [_spec materialKey], [_mesh name], channelCount, @"1");
			}
		}
	}
	
	if (!haveTexCoords)
	{
		[_fragmentPreTextures appendString:@"\tvec2 texCoords = vTexCoords;\n"];
	}
}


- (void) writeDiffuseColorTermIfNeeded
{
	OOTextureSpecification	*diffuseMap = [_spec diffuseMap];
	OOColor					*diffuseColor = [_spec diffuseColor];
	
	if ([diffuseColor isBlack])  return;
	_usesDiffuseTerm = YES;
	
	BOOL haveDiffuseColor = NO;
	if (diffuseMap != nil)
	{
		NSString *readInstr = [self readRGBForTextureSpec:diffuseMap mapName:@"diffuse"];
		if (EXPECT_NOT(readInstr == nil))
		{
			[_fragmentBody appendString:@"\t// INVALID EXTRACTION KEY\n\t\n"];
		}
		else
		{
			[_fragmentBody appendFormat:@"\tvec3 diffuseColor = %@;\n", readInstr];
			 haveDiffuseColor = YES;
		}
	}
	
	if (!haveDiffuseColor || ![diffuseColor isWhite])
	{
		float rgba[4];
		[diffuseColor getRed:&rgba[0] green:&rgba[1] blue:&rgba[2] alpha:&rgba[3]];
		NSString *format = nil;
		if (haveDiffuseColor)
		{
			format = @"\tdiffuseColor *= vec3(%g, %g, %g);\n";
		}
		else
		{
			format = @"\tconst vec3 diffuseColor = vec3(%g, %g, %g);\n";
			haveDiffuseColor = YES;
		}
		[_fragmentBody appendFormat:format, rgba[0], rgba[1], rgba[2]];
	}
	
	[_fragmentBody appendString:@"\t\n"];
}


- (void) writeDiffuseColorTerm
{
	REQUIRE_STAGE(writeDiffuseColorTermIfNeeded);
	
	if (!_usesDiffuseTerm)
	{
		[_fragmentBody appendString:@"\tconst vec3 diffuseColor = vec3(0.0);  // Diffuse colour is black.\n\t\n"];
	}
}


- (void) writeDiffuseLighting
{
	REQUIRE_STAGE(writeDiffuseColorTermIfNeeded);
	if (!_usesDiffuseTerm)  return;
	
	if ([self lightingMode] == kLightingUniform)
	{
		[_fragmentBody appendString:
		@"\t// No lighting because the mesh has no normals.\n"
		 "\ttotalColor += diffuseColor;\n\t\n"];
		return;
	}
	
	REQUIRE_STAGE(writeTotalColor);
	REQUIRE_STAGE(writeVertexPosition);
	REQUIRE_STAGE(writeNormalIfNeeded);
	REQUIRE_STAGE(writeLightVector);
	
	// Simple placeholder lighting based on legacy OpenGL lighting.
	NSString *normalDotLight = _constZNormal ? @"lightVector.z" : @"dot(normal, lightVector)";
	
	// Shared code for all lighting modes.
	[_fragmentBody appendFormat:
	@"\t// Placeholder diffuse lighting\n"
	 "\tvec3 diffuseLight = vec3(0.8 * max(0.0, %@) + 0.2);\n"
	 "\ttotalColor += diffuseColor * diffuseLight;\n\t\n",
	 normalDotLight];
}


- (void) writeLightVector
{
	REQUIRE_STAGE(writeVertexPosition);
	REQUIRE_STAGE(writeNormalIfNeeded);
	
	[self addVarying:@"vLightVector" ofType:@"vec3"];
	
	switch ([self lightingMode])
	{
		case kLightingNormalOnly:
			[_vertexBody appendString:@"\tvLightVector = gl_LightSource[0].position.xyz;\n\t\n"];
			break;
			
		case kLightingNormalTangent:
		case kLightingTangentBitangent:
			[_vertexBody appendString:
			@"\tvec3 lightVector = gl_LightSource[0].position.xyz;\n"
			 "\tvLightVector = lightVector * TBN;\n\t\n"];
			break;
			
		case kLightingUndetermined:
		case kLightingUniform:
			OOReportError(_problemReporter, @"Internal error in shader synthesizer: writeNormalIfNeeded was called in uniform lighting mode.");
			[NSException raise:NSInternalInconsistencyException format:@"lighting logic error"];
			break;
	}
	
	[_fragmentBody appendFormat:@"\tvec3 lightVector = normalize(vLightVector);\n\t\n"];
}


- (void) writeEyeVector
{
	REQUIRE_STAGE(writeVertexPosition);
	REQUIRE_STAGE(writeVertexTangentBasis);
	
	[self addVarying:@"vEyeVector" ofType:@"vec3"];
	
	switch ([self lightingMode])
	{
		case kLightingUndetermined:
		case kLightingUniform:
		case kLightingNormalOnly:
			[_vertexBody appendString:@"\tvEyeVector = position.xyz;\n"];
			break;
			
		case kLightingNormalTangent:
		case kLightingTangentBitangent:
			REQUIRE_STAGE(writeVertexTangentBasis);
			[_vertexBody appendString:@"\tvEyeVector = position.xyz * TBN;\n\t\n"];
			break;
	}
	
	[_fragmentPreTextures appendString:@"\tvec3 eyeVector = normalize(vEyeVector);\n\t\n"];
}


- (void) writeVertexTangentBasis
{
	switch ([self lightingMode])
	{
		case kLightingNormalTangent:
			[self addAttribute:@"aNormal" ofType:@"vec3"];
			[self addAttribute:@"aTangent" ofType:@"vec3"];
			[_vertexBody appendString:
			 @"\t// Build tangent space basis\n"
			 "\tvec3 n = gl_NormalMatrix * aNormal;\n"
			 "\tvec3 t = gl_NormalMatrix * aTangent;\n"
			 "\tvec3 b = cross(n, t);\n"];
			break;
			
		case kLightingTangentBitangent:
			[self addAttribute:@"aTangent" ofType:@"vec3"];
			[self addAttribute:@"aBitangent" ofType:@"vec3"];
			[_vertexBody appendString:
			 @"\t// Build tangent space basis\n"
			 "\tvec3 t = gl_NormalMatrix * aTangent;\n"
			 "\tvec3 b = gl_NormalMatrix * aBitangent;\n"
			 "\tvec3 n = cross(t, b);\n"];
			break;
			
		case kLightingUndetermined:
		case kLightingUniform:
		case kLightingNormalOnly:
			OOReportError(_problemReporter, @"Internal error in shader synthesizer: writeVertexTangentBasis was called in non-tangent-space lighting mode.");
			[NSException raise:NSInternalInconsistencyException format:@"lighting logic error"];
	}
	
	[_vertexBody appendString:@"\tmat3 TBN = mat3(t, b, n);\n\t\n"];
}


- (void) writeNormalIfNeeded
{
	REQUIRE_STAGE(writeVertexPosition);
	
	BOOL canNormalMap = NO, tangentSpace = NO;
	switch ([self lightingMode])
	{
		case kLightingNormalOnly:
			[self addAttribute:@"aNormal" ofType:@"vec3"];
			[self addVarying:@"vNormal" ofType:@"vec3"];
			[_vertexBody appendString:@"\tvNormal = gl_NormalMatrix * aNormal;\n\t\n"];
			[_fragmentBody appendString:@"\tvec3 normal = normalize(vNormal);\n"];
			break;
			
		case kLightingNormalTangent:
		case kLightingTangentBitangent:
			REQUIRE_STAGE(writeVertexTangentBasis);
			tangentSpace = YES;
			break;
			
		case kLightingUndetermined:
		case kLightingUniform:
			break;
	}
	
	OOTextureSpecification *normalMap = [_spec normalMap];
	if (tangentSpace)
	{
		if (normalMap != nil)
		{
			NSString *sample, *swizzle;
			[self getSampleName:&sample andSwizzleOp:&swizzle forTextureSpec:normalMap];
			if (swizzle == nil)  swizzle = @"rgb";
			if ([swizzle length] == 3)
			{
				[_fragmentBody appendFormat:@"\tvec3 normal = normalize(%@.%@);\n\t\n", sample, swizzle];
				_usesNormalMap = YES;
				return;
			}
			else
			{
				OOReportWarning(_problemReporter, @"The %@ map for material \"%@\" of \"%@\" specifies %u channels to extract, but only %@ may be used.", @"normal", [_spec materialKey], [_mesh name], [swizzle length], @"3");
			}
		}
		_constZNormal = YES;
	}
	
	if (!canNormalMap && normalMap != nil)
	{
		OOReportWarning(_problemReporter, @"Material \"%@\" of mesh \"%@\" specifies a normal map, but it cannot be used because the mesh does not provide vertex tangents.", [_spec materialKey], [_mesh name]);
	}
}


- (void) writeNormal
{
	REQUIRE_STAGE(writeNormalIfNeeded);
	
	if (_constZNormal)
	{
		[_fragmentBody appendString:@"\tconst vec3 normal = vec3(0.0, 0.0, 1.0);\n\t\n"];
	}
}


- (void) writeSpecularLighting
{
	if ([self lightingMode] == kLightingUniform)  return;
	float specularExponent = [_spec specularExponent];
	if (specularExponent <= 0)  return;
	OOColor *specularColor = [_spec specularColor];
	if ([specularColor isBlack])  return;
	
	REQUIRE_STAGE(writeTotalColor);
	REQUIRE_STAGE(writeNormalIfNeeded);
	REQUIRE_STAGE(writeEyeVector);
	REQUIRE_STAGE(writeLightVector);
	
	[_fragmentBody appendString:@"\t// Placeholder specular lighting\n"];
	
	BOOL haveSpecularColor = NO;
	OOTextureSpecification *specularColorMap = [_spec specularColorMap];
	if (specularColorMap != nil)
	{
		NSString *readInstr = [self readRGBForTextureSpec:specularColorMap mapName:@"specular colour"];
		if (EXPECT_NOT(readInstr == nil))
		{
			[_fragmentBody appendString:@"\t// INVALID EXTRACTION KEY\n\t\n"];
			return;
		}
		
		[_fragmentBody appendFormat:@"\tvec3 specularColor = %@;\n", readInstr];
		haveSpecularColor = YES;
	}
	
	if (!haveSpecularColor || ![specularColor isWhite])
	{
		float rgba[4];
		[specularColor getRed:&rgba[0] green:&rgba[1] blue:&rgba[2] alpha:&rgba[3]];
		NSString *format = nil;
		if (haveSpecularColor)
		{
			format = @"\tspecularColor *= vec3(%g, %g, %g);\n";
		}
		else
		{
			format = @"\tconst vec3 specularColor = vec3(%g, %g, %g);\n";
			haveSpecularColor = YES;
		}
		[_fragmentBody appendFormat:format, rgba[0] * rgba[3], rgba[1] * rgba[3], rgba[2] * rgba[3]];
	}
	
	OOTextureSpecification *specularExponentMap = [_spec specularExponentMap];
	BOOL haveSpecularExponent = NO;
	if (specularExponentMap != nil)
	{
		NSString *readInstr = [self readOneChannelForTextureSpec:specularExponentMap mapName:@"specular exponent"];
		if (EXPECT_NOT(readInstr == nil))
		{
			[_fragmentBody appendString:@"\t// INVALID EXTRACTION KEY\n\t\n"];
			return;
		}
		
		[_fragmentBody appendFormat:@"\tfloat specularExponent = %@ * %.1f;\n", readInstr, specularExponent];
		haveSpecularExponent = YES;
	}
	if (!haveSpecularExponent)
	{
		[_fragmentBody appendFormat:@"\tconst float specularExponent = %.1f;\n", specularExponent];
	}
	
	if (_usesNormalMap || ![self tangentSpaceLighting])
	{
		[_fragmentBody appendFormat:@"\tvec3 reflection = reflect(lightVector, normal);\n"];
	}
	else
	{
		/*	reflect(I, N) is defined as I - 2 * dot(N, I) * N
			If N is (0,0,1), this becomes (I.x,I.y,-I.z).
		*/
		[_fragmentBody appendFormat:@"\tvec3 reflection = vec3(lightVector.x, lightVector.y, -lightVector.z);\n"];
	}
	
	[_fragmentBody appendFormat:
	@"\tfloat specIntensity = dot(reflection, eyeVector);\n"
	 "\tspecIntensity = pow(max(0.0, specIntensity), specularExponent);\n"
	 "\ttotalColor += specIntensity * specularColor;\n\t\n"];
}


- (void) writeLightMaps
{
	NSArray *lightMaps = [_spec lightMaps];
	NSUInteger idx = 0, count = [lightMaps count];
	
	if (count == 0)  return;
	
	REQUIRE_STAGE(writeTotalColor);
	
	// Illumination maps require diffuse term.
	OOLightMapSpecification *lightMap = nil;
	foreach (lightMap, lightMaps)
	{
		if ([lightMap type] == kOOLightMapTypeIllumination)
		{
			REQUIRE_STAGE(writeDiffuseColorTermIfNeeded);
			break;
		}
	}
	
	[_fragmentBody appendString:@"\tvec3 lightMapColor;\n"];
	
	foreach (lightMap, lightMaps)
	{
		[_fragmentBody appendFormat:@"\t// Light map #%lu\n", idx++];
		
		OOTextureSpecification	*map = [lightMap textureMap];
		OOColor					*color = [lightMap color];
		float					rgba[4];
		
		[color getRed:&rgba[0] green:&rgba[1] blue:&rgba[2] alpha:&rgba[3]];
		rgba[0] *= rgba[3]; rgba[1] *= rgba[3]; rgba[2] *= rgba[3];
		
		if (EXPECT_NOT((rgba[0] == 0.0f && rgba[1] == 0.0f && rgba[2] == 0.0f) ||
					   (!_usesDiffuseTerm && [lightMap type] == kOOLightMapTypeIllumination)))
		{
			[_fragmentBody appendString:@"\t// Light map tinted black has no effect.\n\t\n"];
			continue;
		}
		
		NSString *readInstr = [self readRGBForTextureSpec:map mapName:@"light"];
		if (EXPECT_NOT(readInstr == nil))
		{
			[_fragmentBody appendString:@"\t// INVALID EXTRACTION KEY\n"];
			continue;
		}
		
		[_fragmentBody appendFormat:@"\tlightMapColor = %@;\n", readInstr];
		
		if (rgba[0] != 1.0f || rgba[1] != 1.0f || rgba[2] != 1.0f)
		{
			[_fragmentBody appendFormat:@"\tlightMapColor *= vec3(%g, %g, %g);\n", rgba[0], rgba[1], rgba[2]];
		}
		
		switch ([lightMap type])
		{
			case kOOLightMapTypeEmission:
				[_fragmentBody appendString:@"\ttotalColor += lightMapColor;\n\t\n"];
				break;
				
			case kOOLightMapTypeIllumination:
				[_fragmentBody appendString:@"\ttotalColor += lightMapColor * diffuseColor;\n\t\n"]
					;
				break;
		}
	}
}


- (void) writeVertexPosition
{
	[self addAttribute:@"aPosition" ofType:@"vec3"];
	
	[_vertexBody appendString:
	@"\tvec4 position = gl_ModelViewMatrix * vec4(aPosition, 1.0);\n"
	 "\tgl_Position = gl_ProjectionMatrix * position;\n\t\n"];
}


- (void) writeTotalColor
{
	[_fragmentPreTextures appendString:@"\tvec3 totalColor = vec3(0.0);\n\t\n"];
}


- (void) writeFinalColorComposite
{
	REQUIRE_STAGE(writeTotalColor);	// Needed even if none of the following stages does anything.
	REQUIRE_STAGE(writeDiffuseLighting);
	REQUIRE_STAGE(writeSpecularLighting);
	REQUIRE_STAGE(writeLightMaps);
	
	[_fragmentBody appendString:@"\tgl_FragColor = vec4(totalColor, 1.0);\n\t\n"];
}

@end
