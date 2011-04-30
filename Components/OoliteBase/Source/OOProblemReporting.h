/*
	OOProblemReporting.h
	
	Protocol for reporting multiple errors and other issues.
	
	
	Copyright © 2010 Jens Ayton

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

#import "OOCocoa.h"


typedef enum OOProblemReportType
{
	kOOProblemTypeInformative,
	kOOProblemTypeWarning,
	kOOProblemTypeError
} OOProblemReportType;


@protocol OOProblemReporting <NSObject>

- (void) addProblemOfType:(OOProblemReportType)type message:(NSString *)message;

//	If nil is returned, -[NSBundle localizedStringForKey:value:table:] is used.
- (NSString *) localizedProblemStringForKey:(NSString *)string;

@end


/*	These helper functions will look up keys using -localizedProblemStringForKey:
	or -[NSBundle localizedStringForKey:value:table:] as appropriate.
 */
void OOReportIssueWithArgs(id <OOProblemReporting> probMgr, OOProblemReportType type, NSString *formatKey, va_list args);
void OOReportIssue(id <OOProblemReporting> probMgr, OOProblemReportType type, NSString *formatKey, ...);

void OOReportInfo(id <OOProblemReporting> probMgr, NSString *formatKey, ...);
void OOReportWarning(id <OOProblemReporting> probMgr, NSString *formatKey, ...);
void OOReportError(id <OOProblemReporting> probMgr, NSString *formatKey, ...);

void OOReportNSError(id <OOProblemReporting> probMgr, NSString *context, NSError *error);

NSString *OOLocalizeProblemString(id <OOProblemReporting> probMgr, NSString *string);


/*	Trivial implementation of OOProblemReporting.
	Problems are printed to OOLog. Strings are not localized.
	If contextString is not nil, it is printed before the first problem report.
	messageClassPrefix is prepended to the OOLog message class used for problem
	reports.
*/
@interface OOSimpleProblemReportManager: NSObject <OOProblemReporting>
{
@private
	BOOL					_hadContextString;
	NSString				*_contextString;
	NSString				*_messageClassPrefix;
}

- (id) initWithContextString:(NSString *)context messageClassPrefix:(NSString *)messageClassPrefix;
- (id) initWithMeshFilePath:(NSString *)path forReading:(BOOL)forReading;

@end


/*	Implementation of OOProblemReporting which converts the first reported
	kOOProblemTypeError problem into an NSError.
*/
@interface OOErrorConvertingProblemReporter: NSObject <OOProblemReporting>
{
@private
	NSError					*_error;
	NSString				*_domain;
	NSInteger				_code;
}

- (NSError *) error;

/*	Optionally set error domain and code; defaults are
	kOOErrorConvertingProblemReporterDomain and 1. These will only be effective
	if no error has been reported yet.
*/
- (NSString *) domain;
- (void) setDomain:(NSString *)value;

- (NSInteger) code;
- (void) setCode:(NSInteger)value;

@end


/*	Implementation of OOProblemReporting which converts all errors into
	warnings. (This can be useful when loading ancillary items, for example.)
*/
@interface OOErrorToWarningProblemConverter : NSObject <OOProblemReporting>
{
@private
    id <OOProblemReporting>	_underlyingProblemReporter;
}

- (id) initWithProblemReporter:(id <OOProblemReporting>)problemReporter;
+ (id) converterWithProblemReporter:(id <OOProblemReporting>)problemReporter;

@end


extern NSString * const kOOErrorConvertingProblemReporterDomain;
