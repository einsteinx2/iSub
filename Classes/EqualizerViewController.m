//
//  EqualizerViewController.m
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "EqualizerViewController.h"
#import "EqualizerView.h"
#import "EqualizerPointView.h"
#import "BassWrapperSingleton.h"
#import "BassParamEqValue.h"
#import "BassEffectDAO.h"
#import "UIView+tools.h"
#import "SavedSettings.h"

@implementation EqualizerViewController
@synthesize equalizerView, equalizerPointViews, selectedView, toggleButton, effectDAO, presetPicker, deletePresetButton, savePresetButton, isSavePresetButtonShowing, isDeletePresetButtonShowing, presetNameTextField, saveDialog, gainSlider; //drawTimer;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
	{
		[[UIApplication sharedApplication] setStatusBarHidden:NO animated:YES];
	}
	else
	{
		[[UIApplication sharedApplication] setStatusBarHidden:YES animated:YES];
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	
	if (UIInterfaceOrientationIsPortrait(fromInterfaceOrientation))
	{
		[self removeEqViews];
	}
	else
	{
		[self createEqViews];
	}
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	effectDAO = [[BassEffectDAO alloc] initWithType:BassEffectType_ParametricEQ];

	DLog(@"effectDAO.selectedPresetIndex: %i", effectDAO.selectedPresetIndex);
	[presetPicker selectRow:effectDAO.selectedPresetIndex inComponent:0 animated:NO];
	
	[self updateToggleButton];
	
	[self.equalizerView startEqDisplay];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createEqViews) name:ISMSNotification_BassEffectPresetLoaded object:nil];
	
	isSavePresetButtonShowing = NO;
	self.savePresetButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	CGRect f = presetPicker.frame;
	savePresetButton.frame = CGRectMake(f.origin.x + f.size.width - 60., f.origin.y, 60., 30.);
	[savePresetButton setTitle:@"Save" forState:UIControlStateNormal];
	[savePresetButton addTarget:self action:@selector(promptToSaveCustomPreset) forControlEvents:UIControlEventTouchUpInside];
	savePresetButton.alpha = 0.;
	savePresetButton.enabled = NO;
	[self.view addSubview:savePresetButton];
	
	self.deletePresetButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	deletePresetButton.frame = CGRectMake(f.origin.x + f.size.width - 60., f.origin.y, 60., 30.);
	[deletePresetButton setTitle:@"Delete" forState:UIControlStateNormal];
	[deletePresetButton addTarget:self action:@selector(promptToDeleteCustomPreset) forControlEvents:UIControlEventTouchUpInside];
	deletePresetButton.alpha = 0.;
	deletePresetButton.enabled = NO;
	[self.view addSubview:deletePresetButton];
	
	if (effectDAO.selectedPresetId == BassEffectTempCustomPresetId)
	{
		[self showSavePresetButton:NO];
	}
	else if (![[effectDAO.selectedPreset objectForKey:@"isDefault"] boolValue])
	{
		[self showDeletePresetButton:NO];
	}
	
	gainSlider.value = [SavedSettings sharedInstance].gainMultiplier;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
		[self createEqViews];
	
	[[BassWrapperSingleton sharedInstance] startReadingEqData:ISMS_BASS_EQ_DATA_TYPE_fft];
}

- (void)createEqViews
{
	[self removeEqViews];
	
	equalizerPointViews = [[NSMutableArray alloc] initWithCapacity:0];
	for (BassParamEqValue *value in [BassWrapperSingleton sharedInstance].equalizerValues)
	{
		DLog(@"eq handle: %i", value.handle);
		EqualizerPointView *eqView = [[EqualizerPointView alloc] initWithEqValue:value parentSize:self.equalizerView.frame.size];
		[equalizerPointViews addObject:eqView];
		[self.view addSubview:eqView];
		[eqView release];
	}
	DLog(@"equalizerValues: %@", [BassWrapperSingleton sharedInstance].equalizerValues);
	DLog(@"equalizerViews: %@", equalizerPointViews);
}

- (void)removeEqViews
{
	for (EqualizerPointView *eqView in equalizerPointViews)
	{
		[eqView removeFromSuperview];
	}
	[equalizerPointViews release]; equalizerPointViews = nil;
}

- (void)viewWillDisappear:(BOOL)animated
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_BassEffectPresetLoaded object:nil];
	
	[self removeEqViews];
	
	[self.equalizerView stopEqDisplay];
	
	[equalizerView removeFromSuperview];
	[equalizerView release]; equalizerView = nil;
	
	[[BassWrapperSingleton sharedInstance] stopReadingEqData];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)hideSavePresetButton:(BOOL)animated
{	
	isSavePresetButtonShowing = NO;
	
	if (animated)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
	}
	
	[presetPicker addWidth:65.];
	savePresetButton.alpha = 0.;
	
	if (animated)
	{
		[UIView commitAnimations];
	}
	
	savePresetButton.enabled = NO;
}

- (void)showSavePresetButton:(BOOL)animated
{
	isSavePresetButtonShowing = YES;
	
	savePresetButton.enabled = YES;
	
	if (animated)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
	}
	
	[presetPicker addWidth:-65.];
	savePresetButton.alpha = 1.;
	
	if (animated)
	{
		[UIView commitAnimations];
	}
}

- (void)hideDeletePresetButton:(BOOL)animated
{	
	isDeletePresetButtonShowing = NO;
	
	if (animated)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
	}
	
	[presetPicker addWidth:65.];
	deletePresetButton.alpha = 0.;
	
	if (animated)
	{
		[UIView commitAnimations];
	}
	
	deletePresetButton.enabled = NO;
}

- (void)showDeletePresetButton:(BOOL)animated
{
	isDeletePresetButtonShowing = YES;
	
	deletePresetButton.enabled = YES;
	
	if (animated)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
	}
	
	[presetPicker addWidth:-65.];
	deletePresetButton.alpha = 1.;
	
	if (animated)
	{
		[UIView commitAnimations];
	}
}

- (NSArray *)serializedEqPoints
{
	NSMutableArray *points = [NSMutableArray arrayWithCapacity:0];
	for (EqualizerPointView *pointView in equalizerPointViews)
	{
		[points addObject:NSStringFromCGPoint(pointView.position)];
	}
	return [NSArray arrayWithArray:points];
}

- (void)saveTempCustomPreset
{
	[effectDAO saveTempCustomPreset:[self serializedEqPoints]];
	
	[presetPicker reloadAllComponents];
	[presetPicker selectRow:effectDAO.selectedPresetIndex inComponent:0 animated:NO];
}

- (void)promptToDeleteCustomPreset
{
	NSString *title = [NSString stringWithFormat:@"\"%@\"", [effectDAO.selectedPreset objectForKey:@"name"]];
	UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:title message:@"Are you sure you want to delete this preset?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Delete", nil];
	myAlertView.tag = 1;
	[myAlertView show];
	[myAlertView release];
}

- (void)promptToSaveCustomPreset
{
	NSUInteger count = [effectDAO.userPresets count];
	if ([effectDAO.userPresets objectForKey:[[NSNumber numberWithInt:BassEffectTempCustomPresetId] stringValue]])
		count--;
	
	if (count > 0)
	{
		self.saveDialog = [[DDSocialDialog alloc] initWithFrame:CGRectMake(0., 0., 300., 300.) theme:DDSocialDialogThemeISub];
		saveDialog.dialogDelegate = self;
		saveDialog.titleLabel.text = @"Choose Preset To Save";
		UITableView *saveTable = [[UITableView alloc] initWithFrame:saveDialog.contentView.frame style:UITableViewStylePlain];
		saveTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		saveTable.dataSource = self;
		saveTable.delegate = self;
		[saveDialog.contentView addSubview:saveTable];
		[saveTable release];
		[saveDialog show];
		[saveDialog release];
	}
	else
	{
		[self promptForSavePresetName];
	}
}

- (void)promptForSavePresetName
{
	UIAlertView *myAlertView = [[UIAlertView alloc] initWithTitle:@"New Preset Name:" message:@"      \n      " delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save", nil];
	myAlertView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
	presetNameTextField = [[UITextField alloc] initWithFrame:CGRectMake(12.0, 47.0, 260.0, 22.0)];
	[presetNameTextField setBackgroundColor:[UIColor whiteColor]];
	[myAlertView addSubview:presetNameTextField];
	[presetNameTextField release];
	if ([[[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."] objectAtIndex:0] isEqualToString:@"3"])
	{
		CGAffineTransform myTransform = CGAffineTransformMakeTranslation(0.0, 100.0);
		[myAlertView setTransform:myTransform];
	}
	myAlertView.tag = 2;
	[myAlertView show];
	[myAlertView release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == 1)
	{
		// Delete the preset
		if (buttonIndex)
		{
			[effectDAO deleteCustomPresetForId:effectDAO.selectedPresetId];
			[presetPicker reloadAllComponents];
			[presetPicker selectRow:effectDAO.selectedPresetIndex inComponent:0 animated:YES];
		}
	}
	else
	{
		// Save the preset
		if (buttonIndex)
		{
			DLog(@"Preset name: %@", presetNameTextField.text);
			[effectDAO saveCustomPreset:[self serializedEqPoints] name:presetNameTextField.text];
			[effectDAO deleteTempCustomPreset];
			[presetPicker reloadAllComponents];
			[presetPicker selectRow:effectDAO.selectedPresetIndex inComponent:0 animated:YES];
		}
	}
}

- (IBAction)movedGainSlider:(id)sender
{
	DLog(@"gainSlider.value: %f", gainSlider.value);
	[SavedSettings sharedInstance].gainMultiplier = gainSlider.value;
	[[BassWrapperSingleton sharedInstance] bassSetGainLevel:gainSlider.value];
}

#pragma mark Touch gestures interception

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	// Detect touch anywhere
	UITouch *touch = [touches anyObject];
	DLog(@"touch began");
	
	DLog(@"tap count: %i", [touch tapCount]);
	
	UIView *touchedView = [self.view hitTest:[touch locationInView:self.view] withEvent:nil];
	if ([touchedView isKindOfClass:[EqualizerPointView class]])
	{
		self.selectedView = (EqualizerPointView *)touchedView;
		
		if ([touch tapCount] == 2)
		{
			// remove the point
			DLog(@"double tap, remove point");
			
			[[BassWrapperSingleton sharedInstance] removeEqualizerValue:self.selectedView.eqValue];
			[equalizerPointViews removeObject:self.selectedView];
			[self.selectedView removeFromSuperview];
			self.selectedView = nil;
		}
	}
	else if ([touchedView isKindOfClass:[EqualizerView class]])
	{
		if ([touch tapCount] == 1)
		{
			[self performSelector:@selector(type:) withObject:nil afterDelay:0.25];
		}
		if ([touch tapCount] == 2)
		{
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(type:) object:nil];
			
			// add a point
			DLog(@"double tap, adding point");
			
			// Find the tap point
			CGPoint point = [touch locationInView:self.equalizerView];
			
			// Create the eq view
			EqualizerPointView *eqView = [[EqualizerPointView alloc] initWithCGPoint:point parentSize:self.equalizerView.bounds.size];
			BassParamEqValue *value = [[BassWrapperSingleton sharedInstance] addEqualizerValue:eqView.eqValue.parameters];
			eqView.eqValue = value;
			
			// Add the view
			[equalizerPointViews addObject:eqView];
			[self.view addSubview:eqView];
			[eqView release];
			
			[self saveTempCustomPreset];
			
			return;
		}
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (self.selectedView != nil)
	{
		UITouch *touch = [touches anyObject];
		
		CGPoint location = [touch locationInView:self.equalizerView];
		if (CGRectContainsPoint(equalizerView.frame, location))
		{
			self.selectedView.center = [touch locationInView:self.view];
			[[BassWrapperSingleton sharedInstance] updateEqParameter:self.selectedView.eqValue];
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	// Apply the EQ
	if (self.selectedView != nil)
	{
		[[BassWrapperSingleton sharedInstance] updateEqParameter:self.selectedView.eqValue];
		self.selectedView = nil;
		
		[self saveTempCustomPreset];
	}
}

- (IBAction)dismiss:(id)sender
{
	[self dismissModalViewControllerAnimated:YES];
}

- (IBAction)toggle:(id)sender
{
	if ([[BassWrapperSingleton sharedInstance] toggleEqualizer])
	{
		[self removeEqViews];
		[self createEqViews];
	}
	[self updateToggleButton];
}

- (void)updateToggleButton
{
	if([BassWrapperSingleton sharedInstance].isEqualizerOn)
	{
		[toggleButton setTitle:@"Disable" forState:UIControlStateNormal];
	}
	else
	{
		[toggleButton setTitle:@"Enable" forState:UIControlStateNormal];
	}
}

- (IBAction)type:(id)sender
{
	[equalizerView changeType];
}

#pragma mark -
#pragma mark NWPickerField
#pragma mark -

- (NSInteger)numberOfComponentsInPickerField:(NWPickerField*)pickerField
{
	return 1;
}

- (NSInteger)pickerField:(NWPickerField*)pickerField numberOfRowsInComponent:(NSInteger)component
{
	return [effectDAO.presets count];	
}

- (NSString *)pickerField:(NWPickerField *)pickerField titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
	return [[effectDAO.presetsArray objectAtIndex:row] objectForKey:@"name"];
}

- (void)pickerField:(NWPickerField *)pickerField selectedRow:(NSInteger)row inComponent:(NSInteger)component
{
	[pickerField resignFirstResponder];
	
	[effectDAO selectPresetAtIndex:row];
	
	BOOL isDefault = [[effectDAO.selectedPreset objectForKey:@"isDefault"] boolValue];
	
	if (effectDAO.selectedPresetId == BassEffectTempCustomPresetId && !isSavePresetButtonShowing)
	{
		[self showSavePresetButton:YES];
	}
	else if (effectDAO.selectedPresetId != BassEffectTempCustomPresetId && isSavePresetButtonShowing)
	{
		[self hideSavePresetButton:YES];
	}
	
	if (effectDAO.selectedPresetId != BassEffectTempCustomPresetId && !isDeletePresetButtonShowing && !isDefault)
	{
		[self showDeletePresetButton:YES];
	}
	else if ((effectDAO.selectedPresetId == BassEffectTempCustomPresetId || isDefault) && isDeletePresetButtonShowing)
	{
		[self hideDeletePresetButton:YES];
	}
}

#pragma mark - TableView delegate for save dialog -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{	
	return 2;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section) 
	{
		case 0:
			return 1;
		case 1:
			return [effectDAO.userPresetsArrayMinusCustom count];
		default:
			return 0;
	}
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	
	NSDictionary *preset = nil;
	switch (indexPath.section) 
	{
		case 0:
			cell.textLabel.text = @"New Preset";
			break;
		case 1:
			preset = [effectDAO.userPresetsArrayMinusCustom objectAtIndex:indexPath.row];
			cell.tag = [[preset objectForKey:@"presetId"] intValue];
			cell.textLabel.text = [preset objectForKey:@"name"];
			break;
		default:
			break;
	}
		
	return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	switch (section) 
	{
		case 0:
			return @"";
		case 1:
			return @"Saved Presets";
		default:
			return @"";
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (indexPath.section == 0)
	{
		// Save a new preset
		[self promptForSavePresetName];
	}
	else
	{
		// Save over an existing preset
		UITableViewCell *currentTableCell = [self tableView:tableView cellForRowAtIndexPath:indexPath];
		[effectDAO saveCustomPreset:[self serializedEqPoints] name:currentTableCell.textLabel.text presetId:currentTableCell.tag];
		[effectDAO deleteTempCustomPreset];
		[presetPicker reloadAllComponents];
		[presetPicker selectRow:effectDAO.selectedPresetIndex inComponent:0 animated:YES];
	}
	[saveDialog dismiss:YES];
}


@end