//
//  SettingsTabViewController.m
//  iSub
//
//  Created by Ben Baron on 6/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SettingsTabViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "SocialSingleton.h"
#import "DatabaseSingleton.h"
#import "FoldersViewController.h"
#import "CacheSingleton.h"

#import "SA_OAuthTwitterEngine.h"
#import "SA_OAuthTwitterController.h"

#import "UIDevice+Hardware.h"

#import "NSString+md5.h"
#import "FMDatabaseAdditions.h"

#import "SavedSettings.h"
#import "NSString+Additions.h"
#import "NSArray+Additions.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"
#import "iPhoneStreamingPlayerViewController.h"

@implementation SettingsTabViewController

@synthesize parentController, loadedTime;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settings.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	// Fix for UISwitch/UISegment bug in iOS 4.3 beta 1 and 2
	//
	self.loadedTime = [NSDate date];
	
	settings = [SavedSettings sharedInstance];
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	socialControls = [SocialSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	CacheSingleton *cacheControls = [CacheSingleton sharedInstance];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTwitterUIElements) name:@"twitterAuthenticated" object:nil];
	
	// Set version label
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
#if DEBUG
	NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	versionLabel.text = [NSString stringWithFormat:@"iSub version %@ build %@", build, version];
#else
	versionLabel.text = [NSString stringWithFormat:@"iSub version %@", version];
#endif
	
	// Main Settings
	enableScrobblingSwitch.on = settings.isScrobbleEnabled;
	
	//scrobblePercentSlider.value = [[appDelegate.settingsDictionary objectForKey:@"scrobblePercentSetting"] floatValue];
	scrobblePercentSlider.value = settings.scrobblePercent;
	[self updateScrobblePercentLabel];
	
	manualOfflineModeSwitch.on = settings.isForceOfflineMode;
	
	checkUpdatesSwitch.on = settings.isUpdateCheckEnabled;
	
	autoReloadArtistSwitch.on = settings.isAutoReloadArtistsEnabled;

	disablePopupsSwitch.on = !settings.isPopupsEnabled;
	
	disableRotationSwitch.on = settings.isRotationLockEnabled;
	
	disableScreenSleepSwitch.on = !settings.isScreenSleepEnabled;
	
	enableBasicAuthSwitch.on = settings.isBasicAuthEnabled;
	
	enableSongsTabSwitch.on = settings.isSongsTabEnabled;
	DLog(@"isSongsTabEnabled: %i", settings.isSongsTabEnabled);
	
	recoverSegmentedControl.selectedSegmentIndex = settings.recoverSetting;
	
	maxBitrateWifiSegmentedControl.selectedSegmentIndex = settings.maxBitrateWifi;
	maxBitrate3GSegmentedControl.selectedSegmentIndex = settings.maxBitrate3G;
		
	enableSwipeSwitch.on = settings.isSwipeEnabled;
	enableTapAndHoldSwitch.on = settings.isTapAndHoldEnabled;
	
	enableLyricsSwitch.on = settings.isLyricsEnabled;
	enableCacheStatusSwitch.on = settings.isCacheStatusEnabled;
	
	// Cache Settings
	enableSongCachingSwitch.on = settings.isSongCachingEnabled;
	enableNextSongCacheSwitch.on = settings.isNextSongCacheEnabled;
	enableNextSongPartialCacheSwitch.on = settings.isPartialCacheNextSong;
		
	totalSpace = cacheControls.totalSpace;
	freeSpace = cacheControls.freeSpace;
	freeSpaceLabel.text = [NSString stringWithFormat:@"Free space: %@", [NSString formatFileSize:freeSpace]];
	totalSpaceLabel.text = [NSString stringWithFormat:@"Total space: %@", [NSString formatFileSize:totalSpace]];
	float percentFree = (float) freeSpace / (float) totalSpace;
	CGRect frame = freeSpaceBackground.frame;
	frame.size.width = frame.size.width * percentFree;
	freeSpaceBackground.frame = frame;
	cachingTypeSegmentedControl.selectedSegmentIndex = settings.cachingType;
	[self toggleCacheControlsVisibility];
	[self cachingTypeToggle];
	
	autoDeleteCacheSwitch.on = settings.isAutoDeleteCacheEnabled;
	
	autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex = settings.autoDeleteCacheType;
	
	cacheSongCellColorSegmentedControl.selectedSegmentIndex = settings.cachedSongCellColorType;
	
	switch (settings.quickSkipNumberOfSeconds) 
	{
		case 5: quickSkipSegmentControl.selectedSegmentIndex = 0; break;
		case 15: quickSkipSegmentControl.selectedSegmentIndex = 1; break;
		case 30: quickSkipSegmentControl.selectedSegmentIndex = 2; break;
		case 45: quickSkipSegmentControl.selectedSegmentIndex = 3; break;
		case 60: quickSkipSegmentControl.selectedSegmentIndex = 4; break;
		case 120: quickSkipSegmentControl.selectedSegmentIndex = 5; break;
		case 300: quickSkipSegmentControl.selectedSegmentIndex = 6; break;
		case 600: quickSkipSegmentControl.selectedSegmentIndex = 7; break;
		case 1200: quickSkipSegmentControl.selectedSegmentIndex = 8; break;
		default: break;
	}
	
	// Twitter settings
	if (socialControls.twitterEngine && socialControls.twitterEngine.isAuthorized)
	{
		twitterEnabledSwitch.enabled = YES;
		if (settings.isTwitterEnabled)
			twitterEnabledSwitch.on = YES;
		else
			twitterEnabledSwitch.on = NO;
		
		twitterSigninButton.imageView.image = [UIImage imageNamed:@"twitter-signout.png"];
		
		twitterStatusLabel.text = [NSString stringWithFormat:@"%@ signed in", [socialControls.twitterEngine username]];
	}
	else
	{
		twitterEnabledSwitch.on = NO;
		twitterEnabledSwitch.enabled = NO;
		
		twitterSigninButton.imageView.image = [UIImage imageNamed:@"twitter-signin.png"];
		
		twitterStatusLabel.text = @"Signed out";
	}
	
	// Handle In App Purchase settings
	if ([SavedSettings sharedInstance].isCacheUnlocked == NO)
	{
		// Caching is disabled, so disable the controls
		enableSongCachingSwitch.enabled = NO; enableSongCachingSwitch.alpha = 0.5;
		enableNextSongCacheSwitch.enabled = NO; enableNextSongCacheSwitch.alpha = 0.5;
		cachingTypeSegmentedControl.enabled = NO; cachingTypeSegmentedControl.alpha = 0.5;
		cacheSpaceSlider.enabled = NO; cacheSpaceSlider.alpha = 0.5;
		autoDeleteCacheSwitch.enabled = NO; autoDeleteCacheSwitch.alpha = 0.5;
		autoDeleteCacheTypeSegmentedControl.enabled = NO; autoDeleteCacheTypeSegmentedControl.alpha = 0.5;
		cacheSongCellColorSegmentedControl.enabled = NO; cacheSongCellColorSegmentedControl.alpha = 0.5;
	}
	
	[cacheSpaceLabel2 addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
}

/*- (void)viewWillAppear:(BOOL)animated
{
	if ([[appDelegate.settingsDictionary objectForKey:@"manualOfflineModeSetting"] isEqualToString:@"YES"])
		manualOfflineModeSwitch.on = YES;
	else
		manualOfflineModeSwitch.on = NO;
}*/

- (void)reloadTwitterUIElements
{
	if (socialControls.twitterEngine)
	{
		twitterEnabledSwitch.enabled = YES;
		//if ([[appDelegate.settingsDictionary objectForKey:@"twitterEnabledSetting"] isEqualToString:@"YES"])
		if (settings.isTwitterEnabled)
			twitterEnabledSwitch.on = YES;
		else
			twitterEnabledSwitch.on = NO;
		
		twitterSigninButton.imageView.image = [UIImage imageNamed:@"twitter-signout.png"];
		
		twitterStatusLabel.text = [NSString stringWithFormat:@"%@ signed in", [socialControls.twitterEngine username]];
	}
	else
	{
		twitterEnabledSwitch.on = NO;
		twitterEnabledSwitch.enabled = NO;
		
		twitterSigninButton.imageView.image = [UIImage imageNamed:@"twitter-signin.png"];

		twitterStatusLabel.text = @"Signed out";
	}
}

- (void)cachingTypeToggle
{
	if (cachingTypeSegmentedControl.selectedSegmentIndex == 0)
	{
		cacheSpaceLabel1.text = @"Minimum free space:";
		//cacheSpaceLabel2.text = [settings formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
		cacheSpaceLabel2.text = [NSString formatFileSize:settings.minFreeSpace];
		//cacheSpaceSlider.value = [[appDelegate.settingsDictionary objectForKey:@"minFreeSpace"] floatValue] / totalSpace;
		cacheSpaceSlider.value = (float)settings.minFreeSpace / totalSpace;
	}
	else if (cachingTypeSegmentedControl.selectedSegmentIndex == 1)
	{
		cacheSpaceLabel1.text = @"Maximum cache size:";
		//cacheSpaceLabel2.text = [settings formatFileSize:[[appDelegate.settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue]];
		cacheSpaceLabel2.text = [NSString formatFileSize:settings.maxCacheSize];
		//cacheSpaceSlider.value = [[appDelegate.settingsDictionary objectForKey:@"maxCacheSize"] floatValue] / totalSpace;
		cacheSpaceSlider.value = (float)settings.maxCacheSize / totalSpace;
	}
}

- (IBAction)segmentAction:(id)sender
{
	if ([[NSDate date] timeIntervalSinceDate:loadedTime] > 0.5)
	{
		if (sender == recoverSegmentedControl)
		{
			settings.recoverSetting = recoverSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == maxBitrateWifiSegmentedControl)
		{
			settings.maxBitrateWifi = maxBitrateWifiSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == maxBitrate3GSegmentedControl)
		{
			settings.maxBitrate3G = maxBitrate3GSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == cachingTypeSegmentedControl)
		{
			settings.cachingType = cachingTypeSegmentedControl.selectedSegmentIndex;
			[self cachingTypeToggle];
		}
		else if (sender == autoDeleteCacheTypeSegmentedControl)
		{
			settings.autoDeleteCacheType = autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == cacheSongCellColorSegmentedControl)
		{
			settings.cachedSongCellColorType = cacheSongCellColorSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == quickSkipSegmentControl)
		{
			switch (quickSkipSegmentControl.selectedSegmentIndex) 
			{
				case 0: settings.quickSkipNumberOfSeconds = 5; break;
				case 1: settings.quickSkipNumberOfSeconds = 15; break;
				case 2: settings.quickSkipNumberOfSeconds = 30; break;
				case 3: settings.quickSkipNumberOfSeconds = 45; break;
				case 4: settings.quickSkipNumberOfSeconds = 60; break;
				case 5: settings.quickSkipNumberOfSeconds = 120; break;
				case 6: settings.quickSkipNumberOfSeconds = 300; break;
				case 7: settings.quickSkipNumberOfSeconds = 600; break;
				case 8: settings.quickSkipNumberOfSeconds = 1200; break;
				default: break;
			}
			
			if (IS_IPAD())
				[appDelegate.ipadRootViewController.menuViewController.playerController quickSecondsSetLabels];
		}
	}
}

- (void)toggleCacheControlsVisibility
{
	if (enableSongCachingSwitch.on)
	{
		enableNextSongCacheLabel.alpha = 1;
		enableNextSongCacheSwitch.enabled = YES;
		enableNextSongCacheSwitch.alpha = 1;
		enableNextSongPartialCacheLabel.alpha = 1;
		enableNextSongPartialCacheSwitch.enabled = YES;
		enableNextSongPartialCacheSwitch.alpha = 1;
		cachingTypeSegmentedControl.enabled = YES;
		cachingTypeSegmentedControl.alpha = 1;
		cacheSpaceLabel1.alpha = 1;
		cacheSpaceLabel2.alpha = 1;
		freeSpaceLabel.alpha = 1;
		totalSpaceLabel.alpha = 1;
		totalSpaceBackground.alpha = .7;
		freeSpaceBackground.alpha = .7;
		cacheSpaceSlider.enabled = YES;
		cacheSpaceSlider.alpha = 1;
		cacheSpaceDescLabel.alpha = 1;
		
		if (!enableNextSongCacheSwitch.on)
		{
			enableNextSongPartialCacheLabel.alpha = .5;
			enableNextSongPartialCacheSwitch.enabled = NO;
			enableNextSongPartialCacheSwitch.alpha = .5;
		}
	}
	else
	{
		enableNextSongCacheLabel.alpha = .5;
		enableNextSongCacheSwitch.enabled = NO;
		enableNextSongCacheSwitch.alpha = .5;
		enableNextSongPartialCacheLabel.alpha = .5;
		enableNextSongPartialCacheSwitch.enabled = NO;
		enableNextSongPartialCacheSwitch.alpha = .5;
		cachingTypeSegmentedControl.enabled = NO;
		cachingTypeSegmentedControl.alpha = .5;
		cacheSpaceLabel1.alpha = .5;
		cacheSpaceLabel2.alpha = .5;
		freeSpaceLabel.alpha = .5;
		totalSpaceLabel.alpha = .5;
		totalSpaceBackground.alpha = .3;
		freeSpaceBackground.alpha = .3;
		cacheSpaceSlider.enabled = NO;
		cacheSpaceSlider.alpha = .5;
		cacheSpaceDescLabel.alpha = .5;
	}
}

- (IBAction)switchAction:(id)sender
{
	if ([[NSDate date] timeIntervalSinceDate:loadedTime] > 0.5)
	{
		if (sender == manualOfflineModeSwitch)
		{
			settings.isForceOfflineMode = manualOfflineModeSwitch.on;
			if (manualOfflineModeSwitch.on)
			{
				[appDelegate enterOfflineModeForce];
			}
			else
			{
				[appDelegate enterOnlineModeForce];
			}
			
			// Handle the moreNavigationController stupidity
			if (appDelegate.currentTabBarController.selectedIndex == 4)
			{
				[appDelegate.currentTabBarController.moreNavigationController popToViewController:[appDelegate.currentTabBarController.moreNavigationController.viewControllers objectAtIndexSafe:1] animated:YES];
			}
			else
			{
				[(UINavigationController*)appDelegate.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
			}
		}
		else if (sender == enableScrobblingSwitch)
		{
			settings.isScrobbleEnabled = enableScrobblingSwitch.on;
		}
		else if (sender == enableSongCachingSwitch)
		{
			settings.isSongCachingEnabled = enableSongCachingSwitch.on;
			[self toggleCacheControlsVisibility];
		}
		else if (sender == enableNextSongCacheSwitch)
		{
			settings.isNextSongCacheEnabled = enableNextSongCacheSwitch.on;
			[self toggleCacheControlsVisibility];
		}
		else if (sender == enableNextSongPartialCacheSwitch)
		{
			settings.isPartialCacheNextSong = enableNextSongPartialCacheSwitch.on;
		}
		else if (sender == autoDeleteCacheSwitch)
		{
			settings.isAutoDeleteCacheEnabled = autoDeleteCacheSwitch.on;
		}
		else if (sender == twitterEnabledSwitch)
		{
			settings.isTwitterEnabled = twitterEnabledSwitch.on;
		}
		else if (sender == checkUpdatesSwitch)
		{
			settings.isUpdateCheckEnabled = checkUpdatesSwitch.on;
		}
		else if (sender == enableLyricsSwitch)
		{
			settings.isLyricsEnabled = enableLyricsSwitch.on;
		}
		else if (sender == enableCacheStatusSwitch)
		{
			settings.isCacheStatusEnabled = enableCacheStatusSwitch.on;
		}
		else if (sender == enableSwipeSwitch)
		{
			settings.isSwipeEnabled = enableSwipeSwitch.on;
		}
		else if (sender == enableTapAndHoldSwitch)
		{
			settings.isTapAndHoldEnabled = enableTapAndHoldSwitch.on;
		}
		else if (sender == autoReloadArtistSwitch)
		{
			settings.isAutoReloadArtistsEnabled = autoReloadArtistSwitch.on;
		}
		else if (sender == disablePopupsSwitch)
		{
			settings.isPopupsEnabled = !disablePopupsSwitch.on;
		}
		else if (sender == enableSongsTabSwitch)
		{
			if (enableSongsTabSwitch.on)
			{
				settings.isSongsTabEnabled = YES;
				
				if (IS_IPAD())
				{
					[appDelegate.ipadRootViewController.menuViewController loadCellContents];
				}
				else
				{
					NSMutableArray *controllers = [NSMutableArray arrayWithArray:appDelegate.mainTabBarController.viewControllers];
					[controllers addObject:appDelegate.allAlbumsNavigationController];
					[controllers addObject:appDelegate.allSongsNavigationController];
					[controllers addObject:appDelegate.genresNavigationController];
					appDelegate.mainTabBarController.viewControllers = controllers;
				}
				
				// Setup the allAlbums database
				databaseControls.allAlbumsDb = [FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@allAlbums.db", databaseControls.databaseFolderPath, [[SavedSettings sharedInstance].urlString md5]]];
				[databaseControls.allAlbumsDb executeUpdate:@"PRAGMA cache_size = 1"];
				if ([databaseControls.allAlbumsDb open] == NO) { DLog(@"Could not open allAlbumsDb."); }
				
				// Setup the allSongs database
				databaseControls.allSongsDb = [FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@allSongs.db", databaseControls.databaseFolderPath, [[SavedSettings sharedInstance].urlString md5]]];
				[databaseControls.allSongsDb executeUpdate:@"PRAGMA cache_size = 1"];
				if ([databaseControls.allSongsDb open] == NO) { DLog(@"Could not open allSongsDb."); }
				
				// Setup the Genres database
				databaseControls.genresDb = [FMDatabase databaseWithPath:[NSString stringWithFormat:@"%@/%@genres.db", databaseControls.databaseFolderPath, [[SavedSettings sharedInstance].urlString md5]]];
				[databaseControls.genresDb executeUpdate:@"PRAGMA cache_size = 1"];
				if ([databaseControls.genresDb open] == NO) { DLog(@"Could not open genresDb."); }
			}
			else
			{
				settings.isSongsTabEnabled = NO;

				if (IS_IPAD())
					[appDelegate.ipadRootViewController.menuViewController loadCellContents];
				else
					[viewObjects orderMainTabBarController];
				
				[databaseControls.allAlbumsDb close];
				[databaseControls.allSongsDb close];
				[databaseControls.genresDb close];
			}
		}
		else if (sender == disableRotationSwitch)
		{
			settings.isRotationLockEnabled = disableRotationSwitch.on;
		}
		else if (sender == disableScreenSleepSwitch)
		{
			settings.isScreenSleepEnabled = !disableScreenSleepSwitch.on;
			[UIApplication sharedApplication].idleTimerDisabled = disableScreenSleepSwitch.on;
		}
		else if (sender == enableBasicAuthSwitch)
		{
			settings.isBasicAuthEnabled = enableBasicAuthSwitch.on;
		}
	}
}

- (IBAction)resetFolderCacheAction
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Reset Album Folder Cache" message:@"Are you sure you want to do this? This clears just the cached folder listings, not the cached songs" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
	alert.tag = 0;
	[alert show];
	[alert release];
}

- (IBAction)resetAlbumArtCacheAction
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Reset Album Art Cache" message:@"Are you sure you want to do this? This will clear all saved album art." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
	alert.tag = 1;
	[alert show];
	[alert release];
}

- (void)resetFolderCache
{
	[databaseControls resetFolderCache];
	[viewObjects hideLoadingScreen];
	[self popFoldersTab];
}

- (void)resetAlbumArtCache
{
	[databaseControls resetCoverArtCache];
	[viewObjects hideLoadingScreen];
	[self popFoldersTab];
}

- (void)popFoldersTab
{
	if (IS_IPAD())
		[appDelegate.artistsNavigationController popToRootViewControllerAnimated:NO];
	else
		[appDelegate.rootViewController.navigationController popToRootViewControllerAnimated:NO];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == 0 && buttonIndex == 1)
	{
		[viewObjects showLoadingScreenOnMainWindowWithMessage:@"Processing"];
		[self performSelector:@selector(resetFolderCache) withObject:nil afterDelay:0.05];
	}
	else if (alertView.tag == 1 && buttonIndex == 1)
	{
		[viewObjects showLoadingScreenOnMainWindowWithMessage:@"Processing"];
		[self performSelector:@selector(resetAlbumArtCache) withObject:nil afterDelay:0.05];
	}
}

- (void)updateCacheSpaceSlider
{
	cacheSpaceSlider.value = ((double)[cacheSpaceLabel2.text fileSizeFromFormat] / (double)totalSpace);
}

- (IBAction)updateMinFreeSpaceLabel
{
	cacheSpaceLabel2.text = [NSString formatFileSize:(unsigned long long int) (cacheSpaceSlider.value * totalSpace)];
}

- (IBAction)updateMinFreeSpaceSetting
{
	if (cachingTypeSegmentedControl.selectedSegmentIndex == 0)
	{
		// Check if the user is trying to assing a higher min free space than is available space - 50MB
		if (cacheSpaceSlider.value * totalSpace > freeSpace - 52428800)
		{
			settings.minFreeSpace = freeSpace - 52428800;
			cacheSpaceSlider.value = ((float)settings.minFreeSpace / (float)totalSpace); // Leave 50MB space
		}
		else if (cacheSpaceSlider.value * totalSpace < 52428800)
		{
			settings.minFreeSpace = 52428800;
			cacheSpaceSlider.value = ((float)settings.minFreeSpace / (float)totalSpace); // Leave 50MB space
		}
		else 
		{
			settings.minFreeSpace = (unsigned long long int) (cacheSpaceSlider.value * (float)totalSpace);
		}
		//cacheSpaceLabel2.text = [NSString formatFileSize:settings.minFreeSpace];
	}
	else if (cachingTypeSegmentedControl.selectedSegmentIndex == 1)
	{
		
		// Check if the user is trying to assign a larger max cache size than there is available space - 50MB
		if (cacheSpaceSlider.value * totalSpace > freeSpace - 52428800)
		{
			settings.maxCacheSize = freeSpace - 52428800;
			cacheSpaceSlider.value = ((float)settings.maxCacheSize / (float)totalSpace); // Leave 50MB space
		}
		else if (cacheSpaceSlider.value * totalSpace < 52428800)
		{
			settings.maxCacheSize = 52428800;
			cacheSpaceSlider.value = ((float)settings.maxCacheSize / (float)totalSpace); // Leave 50MB space
		}
		else
		{
			settings.maxCacheSize = (unsigned long long int) (cacheSpaceSlider.value * totalSpace);
		}
		//cacheSpaceLabel2.text = [NSString formatFileSize:settings.maxCacheSize];
	}
	[self updateMinFreeSpaceLabel];
}

- (IBAction)revertMinFreeSpaceSlider
{
	cacheSpaceLabel2.text = [NSString formatFileSize:settings.minFreeSpace];
	cacheSpaceSlider.value = (float)settings.minFreeSpace / totalSpace;
}

- (IBAction)twitterButtonAction
{
	if (socialControls.twitterEngine)
	{
		//[appDelegate.twitterEngine endUserSession];
		socialControls.twitterEngine = nil;
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"twitterAuthData"];
		[self reloadTwitterUIElements];
	}
	else
	{
		UIViewController *controller = [SA_OAuthTwitterController controllerToEnterCredentialsWithTwitterEngine:socialControls.twitterEngine delegate:socialControls];
		if (controller) 
		{
			if (IS_IPAD())
				[appDelegate.ipadRootViewController presentModalViewController:controller animated:YES];
			else
				[self.parentController presentModalViewController:controller animated:YES];
		}
	}
}

- (IBAction)updateScrobblePercentLabel
{
	NSUInteger percentInt = scrobblePercentSlider.value * 100;
	scrobblePercentLabel.text = [NSString stringWithFormat:@"%i", percentInt];
}

- (IBAction)updateScrobblePercentSetting;
{
	settings.scrobblePercent = scrobblePercentSlider.value;
}

- (void)didReceiveMemoryWarning 
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload 
{
    [super viewDidUnload];
    
	//DLog(@"settigns tab view did unload");
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"twitterAuthenticated" object:nil];
	[parentController release];
}

- (void)dealloc 
{
	[loadedTime release];
    [super dealloc];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	UITableView *tableView = (UITableView *)self.view.superview;
	CGRect rect = CGRectMake(0, 500, 320, 5);
	[tableView scrollRectToVisible:rect animated:NO];
	rect = UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? CGRectMake(0, 1600, 320, 5) : CGRectMake(0, 1455, 320, 5);
	[tableView scrollRectToVisible:rect animated:NO];
}

// This dismisses the keyboard when the "done" button is pressed
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[self updateMinFreeSpaceSetting];
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidChange:(UITextField *)textField
{
	[self updateCacheSpaceSlider];
	DLog(@"file size: %llu   formatted: %@", [textField.text fileSizeFromFormat], [NSString formatFileSize:[textField.text fileSizeFromFormat]]);
}

@end
