//
//  PXDocumentController.m
//  Pixen
//


//This class is the application delegate.
//it respond as delegate for  applicationShouldOpenUntitledFile: 
//applicationDidFinishLaunching: applicationWillTerminate: 
//methods (see NSApplication documentation)
// it also responds to message from menu (only menu ??) 
// TODO : finish that 

#import "PXDocumentController.h"
#import "PXDocument.h"
#import "PXWelcomeController.h"
#import "PXPreferencesController.h"
#import "PXCanvasWindowController.h"
#import "PXCanvasWindowController_IBActions.h"
#import "PXCanvasController.h"
#import "PXCanvasDocument.h"
#import "PXAnimationDocument.h"
#import "PXImageSizePrompter.h"
#import "PXLayer.h"
#import "PXCanvas.h"
#import "PXPalette.h"
#import "PXPanelManager.h"
#import "PathUtilities.h"
#import "PXToolPaletteController.h"
#import "PXToolSwitcher.h"
#import "PXTool.h"
#import "PXCanvasView.h"
#import "PXCel.h"
#import "PXAnimation.h"
#import "PXPaletteImporter.h"
#import "PXPatternEditorController.h"

#import "PXCanvas_ImportingExporting.h"

#if GTK
	#import <Sparkle/Sparkle.h>
#endif

#import "Pixen-Swift.h"

/***********************************/
/******** Private method ***********/
/***********************************/

@interface PXDocumentController (Private)
//Call from applicationDidFinishLaunching:
- (void) _createApplicationSupportSubdirectories;
@end

@implementation PXDocumentController (Private)

//TODO Create Subdirectories for colors too
- (void) _createApplicationSupportSubdirectory:(NSString *)sub
								   inDirectory:(NSString *)root
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	BOOL isDir;
	NSString *path = [root stringByAppendingPathComponent:sub];
	
	if(![fileManager fileExistsAtPath:path isDirectory:&isDir])
	{
		NSError *err=nil;
		if (![fileManager createDirectoryAtPath:path 
					withIntermediateDirectories:YES 
									 attributes:nil 
										  error:&err] ) 
		{
			[self presentError:err];
			return;
		}
	}
	else
	{
		if(!isDir) 
		{
			[NSException raise:@"Directory Error" format:@"Couldn't create Pixen support directory."];
			return;
		}
	}	
}
NSString *appSupportSubdirName = @"Pixen";
NSString *backgroundsSubdirName = @"Backgrounds";
NSString *backgroundPresetSubdirName = @"Presets";
NSString *presetsSubdirName = @"Presets";
NSString *palettesSubdirName = @"Palettes";

- (void) _createApplicationSupportSubdirectories
{
	NSString *path = GetApplicationSupportDirectory();
	
	// ./Pixen
	[self _createApplicationSupportSubdirectory:appSupportSubdirName inDirectory:path];   
	
	// ./Pixen/Backgrounds
	path = [path stringByAppendingPathComponent:appSupportSubdirName];
	[self _createApplicationSupportSubdirectory:backgroundsSubdirName inDirectory:path];
	
	
	// ./Pixen/Backgrounds/Presets 
	[self _createApplicationSupportSubdirectory:backgroundPresetSubdirName
									inDirectory:[path stringByAppendingPathComponent:backgroundsSubdirName]]; 
	
	// ./Pixen/Palettes
	[self _createApplicationSupportSubdirectory:palettesSubdirName inDirectory:path];
}
@end


@implementation PXDocumentController

- (void)updateShowsPreviousCelOverlayCache
{
	if ([[NSUserDefaults standardUserDefaults] objectForKey:PXPreviousCelOverlayEnabledKey] == nil)
	{
		cachedShowsPreviousCelOverlay = NO;
		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:PXPreviousCelOverlayEnabledKey];
	}
	else
	{
		cachedShowsPreviousCelOverlay = [[NSUserDefaults standardUserDefaults] boolForKey:PXPreviousCelOverlayEnabledKey];
	}
}

- (IBAction)globalInstallPalette:sender
{
	PXPaletteImporter *importer = [[PXPaletteImporter alloc] init];
	[importer runInWindow:nil];
}

- (IBAction)displayHelp:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/Pixen/Pixen/wiki"]];
}

- (IBAction)displaySupport:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://pixen.uservoice.com/forums/171709-general"]];
}

- (IBAction)purchase:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://itunes.apple.com/us/app/pixen/id525180431?mt=12"]];
}

- (void)checkForUpdates:(id)sender
{
#if GTK
	[[SUUpdater sharedUpdater] checkForUpdates:nil];
#endif
}

//
// Delegate methods
//
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
#if GTK
	[[SUUpdater sharedUpdater] setFeedURL:[NSURL URLWithString:@"http://philippec.github.com/Pixen/appcast.xml"]];
	[[SUUpdater sharedUpdater] setUpdateCheckInterval:60 * 60 * 12];
	[[SUUpdater sharedUpdater] setAutomaticallyChecksForUpdates:YES];
#endif
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	NSString *defaultsPath = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
	[defaults registerDefaults:[NSDictionary dictionaryWithContentsOfFile:defaultsPath]];
	
	[self updateShowsPreviousCelOverlayCache];
	
	//Create some directories needs to store backgrounds and Colors 
	[self _createApplicationSupportSubdirectories];
	
	[[PXPanelManager sharedManager] restorePanelStates];
	
	if ([defaults boolForKey:@"PXActivateColorWellOnStartup"]) {
		[[[PXToolPaletteController sharedToolPaletteController] leftSwitcher] activateColorWell];
	}
	
	//If it is the first time Pixen run launch the welcome Panel
	//TODO (could be cleaner) : Fabien
	if (! [defaults boolForKey:PXHasRunBeforeKey] )
	{
		//id welcome = [[PXWelcomeController alloc] init];
		[defaults setBool:YES forKey:@"PXActivateColorWellOnStartup"];
		[defaults setBool:YES forKey:@"SUCheckAtStartup"];
		[defaults setBool:YES forKey:PXHasRunBeforeKey];
		[defaults synchronize];
		[[NSColorPanel sharedColorPanel] setMode:NSCustomPaletteModeColorPanel];
		[[[PXPanelManager sharedManager] welcomePanel] makeKeyAndOrderFront:self];
		//[welcome showWindow:self];
	}
	
	
	if ( [defaults floatForKey:PXVersionKey] < 3 ) // <3 <3 <3
	{
		[defaults setFloat:3 forKey:@"PXVersion"];
	}
}

- (void)applicationWillResignActive:(NSNotification *)aNotification
{
	for (PXCanvasDocument *current in [self documents])
	{
		[[[current canvasController] view] setAcceptsFirstMouse:NO];
	}
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return NO;
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	if([[filename pathExtension] isEqual:PXBackgroundSuffix])
	{
		id bgName = [filename lastPathComponent];
		id dest = [GetBackgroundPresetsDirectory() stringByAppendingPathComponent:bgName];
		NSInteger result = [[NSAlert alertWithMessageText:[NSString stringWithFormat:NSLocalizedString(@"Install Background Template \"%@\"?", @"Install Background Template \"%@\"?"), bgName] defaultButton:NSLocalizedString(@"Install", @"Install") alternateButton:NSLocalizedString(@"Cancel", @"CANCEL") otherButton:nil informativeTextWithFormat:NSLocalizedString(@"%@ will be copied to %@.", @"%@ will be copied to %@."), [filename stringByAbbreviatingWithTildeInPath], [dest stringByAbbreviatingWithTildeInPath]] runModal];
		if(result == NSAlertDefaultReturn)
		{
			NSError *err=nil;
			if(![[NSFileManager defaultManager] copyItemAtPath:filename toPath:dest error:&err]) 
			{
				[self presentError:err];
				return NO;
			}
			else
			{
				[[NSNotificationCenter defaultCenter] postNotificationName:PXBackgroundTemplateInstalledNotificationName object:self];
			}
		}
	}
	
	if ([[filename pathExtension] isEqual:PXPatternSuffix])
	{
		NSString *patternName = [filename lastPathComponent];
		NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Install pattern '%@'?", @"Install pattern '%@'?"), patternName];
		
		NSInteger result = NSRunAlertPanel(NSLocalizedString(@"Confirmation", @"Confirmation"),
										   message,
										   NSLocalizedString(@"Install", @"Install"),
										   NSLocalizedString(@"CANCEL", @"Cancel"), nil);
		
		if (result == NSAlertDefaultReturn)
		{
			PXPattern *pattern = [NSKeyedUnarchiver unarchiveObjectWithFile:filename];
			
			if (!pattern)
				return NO;
			
			[[PXPatternEditorController sharedController] addPattern:pattern];
		}
		
		return YES;
	}
	
	NSString *ext = [filename pathExtension];
	
	if ([ext isEqual:PXPaletteSuffix] || [ext isEqual:MicrosoftPaletteSuffix] || [ext isEqual:AdobePaletteSuffix] || [ext isEqualToString:GimpPaletteSuffix])
	{
		NSString *paletteName = [filename lastPathComponent];
		NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Install palette '%@'?", @"Install palette '%@'?"), paletteName];
		
		NSInteger result = NSRunAlertPanel(NSLocalizedString(@"Confirmation", @"Confirmation"),
										   message,
										   NSLocalizedString(@"Install", @"Install"),
										   NSLocalizedString(@"CANCEL", @"Cancel"), nil);
		
		if (result == NSAlertDefaultReturn)
		{
			PXPaletteImporter *importer = [[PXPaletteImporter alloc] init];
			[importer importPaletteAtPath:filename];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:PXUserPalettesChangedNotificationName object:self];
		}
		
		return YES;
	}

	NSError *err = nil;
	NSDocument *doc = [self openDocumentWithContentsOfURL:[NSURL fileURLWithPath:filename] display:YES error:&err];
	if(err) {
		[self presentError:err];
	}
	
	return doc != nil;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	[[PXPanelManager sharedManager] archivePanelStates];
}

//IBAction 

- (IBAction)newFromClipboard:(id)sender
{
	NSError *error = nil;
	
	PXCanvasDocument *doc = [self makeUntitledDocumentOfType:PixenImageFileType
											  showSizePrompt:NO
													   error:&error];
	
	if (!doc) {
		[self presentError:error];
		return;
	}
	
	[doc loadFromPasteboard:[NSPasteboard generalPasteboard]];
	
	[self addDocument:doc];
	
	[doc makeWindowControllers];
	[doc showWindows];
}

// It occurs to me (after having renamed this object to be a document controller, of course)
// that this sort of method really should be in, like, an app delegate. But I'm not going
// to deal with that right now.
- (IBAction)toggleAlignmentCrosshairs:sender
{
	BOOL showCrosshairs = [[NSUserDefaults standardUserDefaults] boolForKey:PXCrosshairEnabledKey];
	showCrosshairs = !showCrosshairs;
	[[NSUserDefaults standardUserDefaults] setBool:showCrosshairs forKey:PXCrosshairEnabledKey];
	//FIXME: coupled to canvas window controller
	[[[[self currentDocument] windowControllers] objectAtIndex:0] redrawCanvas:self];
}

- (BOOL)showsPreviousCelOverlay
{
	return cachedShowsPreviousCelOverlay;
}

- (void)togglePreviousCelOverlay:sender
{
	BOOL showPreviousCelOverlay = [[NSUserDefaults standardUserDefaults] boolForKey:PXPreviousCelOverlayEnabledKey];
	cachedShowsPreviousCelOverlay = !showPreviousCelOverlay;
	[[NSUserDefaults standardUserDefaults] setBool:cachedShowsPreviousCelOverlay forKey:PXPreviousCelOverlayEnabledKey];
	//FIXME: coupled to canvas window controller
	[[[self currentDocument] windowControllers] makeObjectsPerformSelector:@selector(redrawCanvas:) withObject:self];
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	if ([anItem action] == @selector(checkForUpdates:)) {
#if GTK
		[anItem setHidden:NO];
#endif
		
		return YES;
	}
	else if ([anItem action] == @selector(purchase:)) {
#if GTK
		[anItem setHidden:NO];
#endif
		
		return YES;
	}
	
	if ([anItem action] == @selector(newFromClipboard:))
	{
		NSPasteboard *board = [NSPasteboard generalPasteboard];
		
		if ([[board types] containsObject:PXLayerPboardType])
			return YES;
		
		for (NSString *type in [NSImage imagePasteboardTypes])
		{
			if ([[board types] containsObject:type])
				return YES;
		}
		
		return NO;
	}
	else if ([anItem action] == @selector(toggleAlignmentCrosshairs:))
	{
		BOOL showCrosshairs = [[NSUserDefaults standardUserDefaults] boolForKey:PXCrosshairEnabledKey];
		[anItem setTitle:(showCrosshairs) ? NSLocalizedString(@"HIDE_ALIGNMENT_CROSSHAIRS", @"Hide Alignment Crosshair") :
		 NSLocalizedString(@"SHOW_ALIGNMENT_CROSSHAIRS", @"Show Alignment Crosshair")];
		return YES;
	}
	else if ([anItem action] == @selector(togglePreviousCelOverlay:))
	{
		[anItem setTitle:([self showsPreviousCelOverlay]) ?
		 NSLocalizedString(@"HIDE_PREVIOUS_FRAME_OVERLAY", nil) :
		 NSLocalizedString(@"SHOW_PREVIOUS_FRAME_OVERLAY", nil)];
		
		return YES;
	}
	else {
		return YES;
	}
}

- (PXAnimationDocument *)handleAnimatedGifAtURL:(NSURL *)aURL
{
    BOOL isAnimated = [GifImporter fileIsAnimatedWithUrl:aURL];
	if (isAnimated)
	{
		NSError *error=nil;
		PXAnimationDocument *doc = [[PXAnimationDocument alloc] initWithContentsOfURL:aURL ofType:(NSString *)kUTTypeGIF error:&error];
		if(error) {
			[self presentError:error];
		}
		return doc;
	}
	return nil;
}

- (BOOL)presentError:(NSError *)error
{
	if ([[error domain] isEqualToString:NSCocoaErrorDomain] && [error code] == 260) {
		return NO; // suppress 'Document could not be created errors' which are the result of returning nil in 'makeUntitledDocumentOfType:error:'
	}
	
	return [super presentError:error];
}

- (id)makeUntitledDocumentOfType:(NSString *)typeName showSizePrompt:(BOOL)showPrompt error:(NSError **)outError
{
	if (!showPrompt) {
		return [super makeUntitledDocumentOfType:typeName error:outError];
	}
	
	PXImageSizePrompter *prompter = [[PXImageSizePrompter alloc] init];
	
	if ([typeName isEqualToString:PixenAnimationFileType]) {
		[prompter.window setTitle:NSLocalizedString(@"NEW_ANIMATION", nil)];
		[prompter.promptField setStringValue:NSLocalizedString(@"ANIMATION_SIZE_PROMPT", nil)];
	}
	
	if (![prompter runModal]) {
		if (outError)
			*outError = nil;
		
		return nil;
	}
	
	id document = [super makeUntitledDocumentOfType:typeName error:outError];
	
	if (!document) {
		return nil;
	}
	
	NSColor *color = [[prompter backgroundColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	
	[[document canvas] setSize:[prompter size] withOrigin:NSZeroPoint backgroundColor:PXColorFromNSColor(color)];
	[document updateChangeCount:NSChangeCleared];
	[[document canvasController] updateCanvasSize];
	
	return document;
}

- (id)makeUntitledDocumentOfType:(NSString *)typeName error:(NSError **)outError
{
	return [self makeUntitledDocumentOfType:typeName showSizePrompt:YES error:outError];
}

- (id)makeDocumentWithContentsOfURL:(NSURL *)url ofType:(NSString *)docType error:(NSError **)err
{
	if (UTTypeEqual(kUTTypeGIF, (__bridge CFStringRef) docType))
	{
		id potentiallyAnimatedDocument = [self handleAnimatedGifAtURL:url];
		if (potentiallyAnimatedDocument)
			return potentiallyAnimatedDocument;
	}
	NSDocument *doc = [super makeDocumentWithContentsOfURL:url ofType:docType error:err];
	if (err && *err) {
		[self presentError:*err];
		return nil;
	}
	return doc;
}

- (id)makeDocumentForURL:(NSURL *)absoluteDocumentURL withContentsOfURL:(NSURL *)absoluteDocumentContentsURL ofType:(NSString *)typeName error:(NSError **)outError
{
	if (UTTypeEqual(kUTTypeGIF, (__bridge CFStringRef)typeName))
	{
		id potentiallyAnimatedDocument = [self handleAnimatedGifAtURL:absoluteDocumentURL];
		if (potentiallyAnimatedDocument)
			return potentiallyAnimatedDocument;
	}
	return [super makeDocumentForURL:absoluteDocumentURL withContentsOfURL:absoluteDocumentContentsURL ofType:typeName error:nil];
}

- (IBAction)newAnimationDocument:sender
{
	NSError *err = nil;
	NSDocument *doc = [self makeUntitledDocumentOfType:PixenAnimationFileType error:&err];
	if(!doc) 
	{
		if (err)
			[self presentError:err];
		
		return;
	}
	[self addDocument:doc];
	[doc makeWindowControllers];
	[doc showWindows];
}

- (IBAction)importAnimationFromImageSequence:sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowsMultipleSelection:YES];
	[openPanel setPrompt:NSLocalizedString(@"Import", @"Import")];
	[openPanel setTitle:NSLocalizedString(@"Import Sequence", @"Import Sequence")];
	
	// Determine the appropriate extensions for the open panel.
	NSArray *longTypes = [PXCanvasDocument readableTypes];
	
	[openPanel setAllowedFileTypes:longTypes];
	[openPanel setAllowsOtherFileTypes:NO];
	[openPanel setCanChooseDirectories:NO];
	
	NSInteger returnCode = [openPanel runModal];
	
	if (returnCode == NSFileHandlingPanelCancelButton)
		return;
	
	PXAnimationDocument *animationDocument = (PXAnimationDocument *)[self makeUntitledDocumentOfType:PixenAnimationFileType showSizePrompt:NO error:nil];
	
	[[animationDocument animation] removeCel:[[animationDocument animation] celAtIndex:0]];
	
	NSArray *urls = [[openPanel URLs] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		
		NSURL *u1 = obj1;
		NSURL *u2 = obj2;
		
		return [[u1 lastPathComponent] compare:[u2 lastPathComponent]];
		
	}];
	
	NSMutableArray *images = [[NSMutableArray alloc] initWithCapacity:[[openPanel URLs] count]];
    for (NSURL *currentURL in urls)
	{
		[images addObject:[PXCanvas canvasWithContentsOfFile:[currentURL path]]];
	}
	
	float defaultDuration = 1.0f;
	for(PXCanvas *current in images)
	{
		[[animationDocument animation] addCel:[[PXCel alloc] initWithCanvas:current duration:defaultDuration]];
	}	
	[self addDocument:animationDocument];
	[animationDocument makeWindowControllers];
	[animationDocument showWindows];
	[animationDocument updateChangeCount:NSChangeReadOtherContents];
}

@end

