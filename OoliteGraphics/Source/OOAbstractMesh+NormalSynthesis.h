/*
	OOAbstractMesh+NormalSynthesis.h
	
	Utilities to calculate normals for meshes. If the mesh had no normals
	before, the new normals attribute will be marked synthetic.
	
	NOTE: smoothing will not work correctly if vertices are non-unique.
	Results will be meaningless if vertices do not have position attributes.
	
	
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

#import "OOAbstractMesh.h"


@interface OOAbstractMesh (NormalSynthesis)

- (BOOL) synthesizeNormalsSmoothly:(BOOL)smooth replacingExisting:(BOOL)replace;
- (BOOL) flipNormals;

@end


@interface OOAbstractFaceGroup (NormalSynthesis)

- (BOOL) synthesizeNormalsSmoothly:(BOOL)smooth replacingExisting:(BOOL)replace;

@end
