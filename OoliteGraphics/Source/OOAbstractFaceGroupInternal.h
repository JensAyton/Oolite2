/*
	OOAbstractFaceGroupInternal.h
	
	Internal, abstraction-breaking methods.
	
	
	Copyright © 2010 Jens Ayton.
	
	Permission is hereby granted, free of charge, to any person obtaining a
	copy of this software and associated documentation files (the “Software”),
	to deal in the Software without restriction, including without limitation
	the rights to use, copy, modify, merge, publish, distribute, sublicense,
	and/or sell copies of the Software, and to permit persons to whom the
	Software is furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
	THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
	DEALINGS IN THE SOFTWARE.
*/

#if !OOLITE_LEAN

#import "OOAbstractFaceGroup.h"


@interface OOAbstractFaceGroup (Internal)

// Must be called whenever face group is mutated.
- (void) internal_becomeDirtyAffectingUniqueness:(BOOL)affectsUniqueness	// True if change may de-unique vertices.
									vertexSchema:(BOOL)affectsSchema		// True if change may affect vertex schema.
									  renderMesh:(BOOL)affectsRenderMesh;	// True if change may affect render mesh or materials.

- (void) internal_replaceAllFaces:(NSMutableArray *)faces
			  affectingUniqueness:(BOOL)affectsUniqueness
					 vertexSchema:(BOOL)affectsSchema
					   renderMesh:(BOOL)affectsRenderMesh;

@end

#endif
