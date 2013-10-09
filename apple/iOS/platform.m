/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2013 - Jason Fetters
 * 
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with RetroArch.
 *  If not, see <http://www.gnu.org/licenses/>.
 */

#include <pthread.h>
#include <string.h>

#import "RetroArch_Apple.h"
#include "rarch_wrapper.h"

#include "apple/common/apple_input.h"
#include "apple/common/setting_data.h"

#import "views.h"
#include "bluetooth/btpad.h"
#include "bluetooth/btdynamic.h"
#include "bluetooth/btpad.h"

#include "file.h"

@protocol RAMenuItemBase
- (UITableViewCell*)cellForTableView:(UITableView*)tableView;
- (void)wasSelectedOnTableView:(UITableView*)tableView;
@end

/*********************************************/
/* RAMenuBase                                */
/* A menu class that displays RAMenuItemBase */
/* objects.                                  */
/*********************************************/
@interface RAMenuBase : RATableViewController @end
@implementation RAMenuBase

- (id)initWithStyle:(UITableViewStyle)style
{
   return [super initWithStyle:style];
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
   return [[self itemForIndexPath:indexPath] cellForTableView:tableView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
   [[self itemForIndexPath:indexPath] wasSelectedOnTableView:tableView];
}

@end

/*********************************************/
/* RAMenuItemBasic                           */
/* A simple menu item that displays a text   */
/* description and calls a block object when */
/* selected.                                 */
/*********************************************/
@interface RAMenuItemBasic : NSObject<RAMenuItemBase>
@property (nonatomic) NSString* description;
@property (nonatomic, strong) void (^action)();
@end

@implementation RAMenuItemBasic

+ (RAMenuItemBasic*)itemWithDescription:(NSString*)description action:(void (^)())action
{
   RAMenuItemBasic* item = [RAMenuItemBasic new];
   item.description = description;
   item.action = action;
   return item;
}

- (UITableViewCell*)cellForTableView:(UITableView*)tableView
{
   static NSString* const cell_id = @"text";
   
   UITableViewCell* result = [tableView dequeueReusableCellWithIdentifier:cell_id];
   if (!result)
      result = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cell_id];
   
   result.textLabel.text = self.description;
   return result;
}

- (void)wasSelectedOnTableView:(UITableView*)tableView
{
   if (self.action)
      self.action();
}

@end

/*********************************************/
/* RAMenuItemBoolean                         */
/* A simple menu item that displays the      */
/* state, and allows editing, of a boolean   */
/* setting.                                  */
/*********************************************/
@interface RAMenuItemBoolean : NSObject<RAMenuItemBase>
@property (nonatomic) const rarch_setting_t* setting;
@end

@implementation RAMenuItemBoolean

+ (RAMenuItemBoolean*)itemForSetting:(const char*)setting_name
{
   RAMenuItemBoolean* item = [RAMenuItemBoolean new];
   item.setting = setting_data_find_setting(setting_name);
   return item;
}

- (UITableViewCell*)cellForTableView:(UITableView*)tableView
{
   static NSString* const cell_id = @"boolean_setting";
   
   UITableViewCell* result = [tableView dequeueReusableCellWithIdentifier:cell_id];
   if (!result)
   {
      result = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cell_id];
      result.selectionStyle = UITableViewCellSelectionStyleNone;
      result.accessoryView = [UISwitch new];
   }

   result.textLabel.text = @(self.setting->short_description);
   [(id)result.accessoryView removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
   [(id)result.accessoryView addTarget:self action:@selector(handleBooleanSwitch:) forControlEvents:UIControlEventValueChanged];
   
   if (self.setting)
      [(id)result.accessoryView setOn:*(bool*)self.setting];
   return result;
}

- (void)handleBooleanSwitch:(UISwitch*)swt
{
   if (self.setting)
      *(bool*)self.setting->value = swt.on ? true : false;
}

- (void)wasSelectedOnTableView:(UITableView*)tableView
{
}

@end

/*********************************************/
/* RAMenuItemString                          */
/* A simple menu item that displays the      */
/* state, and allows editing, of a string or */
/* numeric setting.                          */
/*********************************************/
@interface RAMenuItemString : NSObject<RAMenuItemBase, UIAlertViewDelegate, UITextFieldDelegate>
@property (nonatomic) const rarch_setting_t* setting;
@property (nonatomic) UITableView* parentTable;
@end

@implementation RAMenuItemString

+ (RAMenuItemString*)itemForSetting:(const char*)setting_name
{
   RAMenuItemString* item = [RAMenuItemString new];
   item.setting = setting_data_find_setting(setting_name);
   return item;
}

- (UITableViewCell*)cellForTableView:(UITableView*)tableView
{
   static NSString* const cell_id = @"string_setting";
   
   UITableViewCell* result = [tableView dequeueReusableCellWithIdentifier:cell_id];
   if (!result)
   {
      result = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cell_id];
      result.selectionStyle = UITableViewCellSelectionStyleNone;
   }

   char buffer[256];
   result.textLabel.text = @(self.setting->short_description);

   if (self.setting)
      result.detailTextLabel.text = @(setting_data_get_string_representation(_setting, buffer, sizeof(buffer)));
   return result;
}

- (void)wasSelectedOnTableView:(UITableView*)tableView
{
   self.parentTable = tableView;

   UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Enter new value" message:@(_setting->short_description) delegate:self
                                                  cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
   alertView.alertViewStyle = UIAlertViewStylePlainTextInput;

   UITextField* field = [alertView textFieldAtIndex:0];
   char buffer[256];
   
   field.delegate = self;
   field.text = @(setting_data_get_string_representation(_setting, buffer, sizeof(buffer)));
   field.keyboardType = (_setting->type == ST_INT || _setting->type == ST_FLOAT) ? UIKeyboardTypeDecimalPad : UIKeyboardTypeDefault;

   [alertView show];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
   if (_setting->type == ST_INT || _setting->type == ST_FLOAT)
   {
      RANumberFormatter* formatter = [[RANumberFormatter alloc] initWithFloatSupport:_setting->type == ST_FLOAT
                                                                minimum:_setting->min maximum:_setting->max];

      NSString* result = [textField.text stringByReplacingCharactersInRange:range withString:string];
      return [formatter isPartialStringValid:result newEditingString:nil errorDescription:nil];
   }

   return YES;
}


- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
   NSString* text = [alertView textFieldAtIndex:0].text;

   if (buttonIndex == alertView.firstOtherButtonIndex && text.length)
   {
      setting_data_set_with_string_representation(_setting, text.UTF8String);
      
      [self.parentTable reloadData];
      self.parentTable = nil;
   }
}

@end


/*********************************************/
/* RAMainMenu                                */
/* Menu object that is displayed immediately */
/* after startup.                            */
/*********************************************/
@interface RAMainMenu : RAMenuBase @end
@implementation RAMainMenu

- (id)init
{
   if ((self = [super initWithStyle:UITableViewStylePlain]))
   {
      self.title = @"RetroArch";
   
      self.sections =
      @[
         @[
            @"",
            [RAMenuItemBasic itemWithDescription:@"Core"                      action:^{ [self selectCore];   }],
            [RAMenuItemBasic itemWithDescription:@"Load Game (Core)"          action:^{ [self loadGame];     }],
            [RAMenuItemBasic itemWithDescription:@"Load Game (History)"       action:^{ [self loadGame];     }],
            [RAMenuItemBasic itemWithDescription:@"Load Game (Detect Core)"   action:^{ [self loadGame];     }],
            [RAMenuItemBasic itemWithDescription:@"Settings"                  action:^{ [self showSettings]; }],
            [RAMenuItemBoolean itemForSetting:"video_fullscreen"],
            [RAMenuItemString itemForSetting:"audio_device"],
            [RAMenuItemString itemForSetting:"video_monitor_index"]
         ]
      ];
   }
   
   return self;
}

- (void)selectCore
{
   printf("HAHA\n");
}

- (void)loadGame
{
   printf("HOHO\n");
}

- (void)showSettings
{
   [self.navigationController pushViewController:[RASystemSettingsList new] animated:YES];
}

@end


//#define HAVE_DEBUG_FILELOG
bool is_ios_7()
{
   return [[UIDevice currentDevice].systemVersion compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending;
}

void ios_set_bluetooth_mode(NSString* mode)
{
   if (!is_ios_7())
   {
      apple_input_enable_icade([mode isEqualToString:@"icade"]);
      btstack_set_poweron([mode isEqualToString:@"btstack"]);
   }
#ifdef __IPHONE_7_0 // iOS7 iCade Support
   else
   {
      bool enabled = [mode isEqualToString:@"icade"];
      apple_input_enable_icade(enabled);
      [[RAGameView get] iOS7SetiCadeMode:enabled];
   }
#endif
}

// Input helpers: This is kept here because it needs objective-c
static void handle_touch_event(NSArray* touches)
{
   const int numTouches = [touches count];
   const float scale = [[UIScreen mainScreen] scale];

   g_current_input_data.touch_count = 0;
   
   for(int i = 0; i != numTouches && g_current_input_data.touch_count < MAX_TOUCHES; i ++)
   {
      UITouch* touch = [touches objectAtIndex:i];
      const CGPoint coord = [touch locationInView:touch.view];

      if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled)
      {
         g_current_input_data.touches[g_current_input_data.touch_count   ].screen_x = coord.x * scale;
         g_current_input_data.touches[g_current_input_data.touch_count ++].screen_y = coord.y * scale;
      }
   }
}

@interface RApplication : UIApplication
@end

@implementation RApplication

- (void)sendEvent:(UIEvent *)event
{
   [super sendEvent:event];
   
   if ([[event allTouches] count])
      handle_touch_event(event.allTouches.allObjects);
   else if ([event respondsToSelector:@selector(_gsEvent)])
   {   
      // Stolen from: http://nacho4d-nacho4d.blogspot.com/2012/01/catching-keyboard-events-in-ios.html
      uint8_t* eventMem = (uint8_t*)(void*)CFBridgingRetain([event performSelector:@selector(_gsEvent)]);
      int eventType = eventMem ? *(int*)&eventMem[8] : 0;

      if (eventType == GSEVENT_TYPE_KEYDOWN || eventType == GSEVENT_TYPE_KEYUP)
         apple_input_handle_key_event(*(uint16_t*)&eventMem[0x3C], eventType == GSEVENT_TYPE_KEYDOWN);

      CFBridgingRelease(eventMem);
   }
}

#ifdef __IPHONE_7_0 // iOS7 iCade Support

- (NSArray*)keyCommands
{
   static NSMutableArray* key_commands;

   if (!key_commands)
   {
      key_commands = [NSMutableArray array];
   
      for (int i = 0; i != 26; i ++)
      {
         [key_commands addObject:[UIKeyCommand keyCommandWithInput:[NSString stringWithFormat:@"%c", 'a' + i]
                                               modifierFlags:0 action:@selector(keyGotten:)]];
      }
   }

   return key_commands;
}

- (void)keyGotten:(UIKeyCommand *)keyCommand
{
   apple_input_handle_key_event([keyCommand.input characterAtIndex:0] - 'a' + 4, true);
}

#endif

@end

@implementation RetroArch_iOS
{
   UIWindow* _window;
   NSString* _path;

   bool _isGameTop, _isRomList;
   uint32_t _settingMenusInBackStack;
   uint32_t _enabledOrientations;
}

+ (RetroArch_iOS*)get
{
   return (RetroArch_iOS*)[[UIApplication sharedApplication] delegate];
}

#pragma mark LIFECYCLE (UIApplicationDelegate)
- (void)applicationDidFinishLaunching:(UIApplication *)application
{
   apple_platform = self;
   self.delegate = self;

   // Setup window
   _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
   _window.rootViewController = self;
   [_window makeKeyAndVisible];

   // Build system paths and test permissions
   self.documentsDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
   self.systemDirectory = [self.documentsDirectory stringByAppendingPathComponent:@".RetroArch"];
   self.systemConfigPath = [self.systemDirectory stringByAppendingPathComponent:@"frontend.cfg"];
   
   self.configDirectory = self.systemDirectory;
   self.globalConfigFile = [NSString stringWithFormat:@"%@/retroarch.cfg", self.configDirectory];
   self.coreDirectory = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"modules"];

   if (!path_make_and_check_directory(self.documentsDirectory.UTF8String, 0755, R_OK | W_OK | X_OK))
      apple_display_alert([NSString stringWithFormat:@"Failed to create or access base directory: %@", self.documentsDirectory], 0);
   else if (!path_make_and_check_directory(self.systemDirectory.UTF8String, 0755, R_OK | W_OK | X_OK))
      apple_display_alert([NSString stringWithFormat:@"Failed to create or access system directory: %@", self.systemDirectory], 0);
   else
      [self beginBrowsingForFile];

   
   // Warn if there are no cores present
   if (apple_get_modules().count == 0)
      apple_display_alert(@"No libretro cores were found. You will not be able to play any games.", 0);
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
   apple_exit_stasis(false);
}

- (void)applicationWillResignActive:(UIApplication *)application
{
   apple_enter_stasis();
}

#pragma mark Frontend Browsing Logic
-(BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
   NSString* filename = url.path.lastPathComponent;

   NSError* error = nil;
   [NSFileManager.defaultManager moveItemAtPath:url.path toPath:[self.documentsDirectory stringByAppendingPathComponent:filename] error:&error];
   
   if (error)
      printf("%s\n", error.description.UTF8String);
   
   return true;
}

- (void)beginBrowsingForFile
{
   NSString* rootPath = RetroArch_iOS.get.documentsDirectory;
   NSString* ragPath = [rootPath stringByAppendingPathComponent:@"RetroArchGames"];
   NSString* target = path_is_directory(ragPath.UTF8String) ? ragPath : rootPath;
   
   [self pushViewController:[[RADirectoryList alloc] initWithPath:target delegate:self] animated:YES];

   [self refreshSystemConfig];
   if (apple_use_tv_mode)
      apple_run_core(nil, 0);
   
}

- (bool)directoryList:(id)list itemWasSelected:(RADirectoryItem*)path
{
   if(path.isDirectory)
      [self pushViewController:[[RADirectoryList alloc] initWithPath:path.path delegate:self] animated:YES];
   else
   {
      _path = path.path;
   
      if (access([path.path stringByDeletingLastPathComponent].UTF8String, R_OK | W_OK | X_OK))
         apple_display_alert(@"The directory containing the selected file has limited permissions. This may "
                              "prevent zipped games from loading, and will cause some cores to not function.", 0);

      [self pushViewController:[[RAModuleList alloc] initWithGame:path.path delegate:self] animated:YES];
   }
   
   return true;
}

- (bool)moduleList:(id)list itemWasSelected:(RAModuleInfo*)module
{
   apple_run_core(module, _path.UTF8String);
   return true;
}

// UINavigationControllerDelegate
- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
   _isGameTop = [viewController isKindOfClass:[RAGameView class]];
   _isRomList = [viewController isKindOfClass:[RADirectoryList class]];

   [[UIApplication sharedApplication] setStatusBarHidden:_isGameTop withAnimation:UIStatusBarAnimationNone];
   [[UIApplication sharedApplication] setIdleTimerDisabled:_isGameTop];

   self.navigationBarHidden = _isGameTop;
   [self setToolbarHidden:!_isRomList animated:YES];
   self.topViewController.navigationItem.rightBarButtonItem = [self createSettingsButton];
}

// UINavigationController: Never animate when pushing onto, or popping, an RAGameView
- (void)pushViewController:(UIViewController*)theView animated:(BOOL)animated
{
   apple_input_reset_icade_buttons();

   if ([theView respondsToSelector:@selector(isSettingsView)] && [(id)theView isSettingsView])
      _settingMenusInBackStack ++;

   [super pushViewController:theView animated:animated && !_isGameTop];
}

- (UIViewController*)popViewControllerAnimated:(BOOL)animated
{
   apple_input_reset_icade_buttons();

   if ([self.topViewController respondsToSelector:@selector(isSettingsView)] && [(id)self.topViewController isSettingsView])
      _settingMenusInBackStack --;

   return [super popViewControllerAnimated:animated && !_isGameTop];
}

// NOTE: This version only runs on iOS6
- (NSUInteger)supportedInterfaceOrientations
{
   return _isGameTop ? _enabledOrientations
                     : UIInterfaceOrientationMaskAll;
}

// NOTE: This version runs on iOS2-iOS5, but not iOS6
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
   if (_isGameTop)
      switch (interfaceOrientation)
      {
         case UIInterfaceOrientationPortrait:
            return (_enabledOrientations & UIInterfaceOrientationMaskPortrait);
         case UIInterfaceOrientationPortraitUpsideDown:
            return (_enabledOrientations & UIInterfaceOrientationMaskPortraitUpsideDown);
         case UIInterfaceOrientationLandscapeLeft:
            return (_enabledOrientations & UIInterfaceOrientationMaskLandscapeLeft);
         case UIInterfaceOrientationLandscapeRight:
            return (_enabledOrientations & UIInterfaceOrientationMaskLandscapeRight);
      }
   
   return YES;
}


#pragma mark RetroArch_Platform
- (void)loadingCore:(RAModuleInfo*)core withFile:(const char*)file
{
   [self pushViewController:RAGameView.get animated:NO];
   [RASettingsList refreshModuleConfig:core];

   btpad_set_inquiry_state(false);

   [self refreshSystemConfig];
}

- (void)unloadingCore:(RAModuleInfo*)core
{
   [self popToViewController:[RAGameView get] animated:NO];
   [self popViewControllerAnimated:NO];
      
   btpad_set_inquiry_state(true);
}

#pragma mark FRONTEND CONFIG
- (void)refreshSystemConfig
{
   // Read load time settings
   config_file_t* conf = config_file_new([self.systemConfigPath UTF8String]);

   // Get enabled orientations
   static const struct { const char* setting; uint32_t orientation; } orientationSettings[4] =
   {
      { "ios_allow_portrait", UIInterfaceOrientationMaskPortrait },
      { "ios_allow_portrait_upside_down", UIInterfaceOrientationMaskPortraitUpsideDown },
      { "ios_allow_landscape_left", UIInterfaceOrientationMaskLandscapeLeft },
      { "ios_allow_landscape_right", UIInterfaceOrientationMaskLandscapeRight }
   };
   
   _enabledOrientations = 0;
   
   for (int i = 0; i < 4; i ++)
   {
      bool enabled = false;
      bool found = conf && config_get_bool(conf, orientationSettings[i].setting, &enabled);
         
      if (!found || enabled)
         _enabledOrientations |= orientationSettings[i].orientation;
   }

   if (conf)
   {
      // Setup bluetooth mode
      ios_set_bluetooth_mode(objc_get_value_from_config(conf, @"ios_btmode", @"keyboard"));

      bool val;
      apple_use_tv_mode = config_get_bool(conf, "ios_tv_mode", &val) && val;
      
      config_file_free(conf);
   }
}

#pragma mark PAUSE MENU
- (UIBarButtonItem*)createSettingsButton
{
   if (_settingMenusInBackStack == 0)
      return [[UIBarButtonItem alloc]
            initWithTitle:@"Settings"
                    style:UIBarButtonItemStyleBordered
                   target:[RetroArch_iOS get]
                   action:@selector(showSystemSettings)];
   
   else
      return nil;
}

- (IBAction)showPauseMenu:(id)sender
{
   if (apple_is_running && !apple_is_paused && _isGameTop)
   {
      apple_is_paused = true;
      [[RAGameView get] openPauseMenu];
      
      btpad_set_inquiry_state(true);
   }
}

- (IBAction)basicEvent:(id)sender
{
   if (apple_is_running)
      apple_frontend_post_event(&apple_event_basic_command, ((UIView*)sender).tag);
   
   [self closePauseMenu:sender];
}

- (IBAction)chooseState:(id)sender
{
   if (apple_is_running)
      apple_frontend_post_event(apple_event_set_state_slot, (void*)((UISegmentedControl*)sender).selectedSegmentIndex);
}

- (IBAction)showRGUI:(id)sender
{
   if (apple_is_running)
      apple_frontend_post_event(apple_event_show_rgui, 0);
   
   [self closePauseMenu:sender];
}

- (IBAction)closePauseMenu:(id)sender
{
   [[RAGameView get] closePauseMenu];
   apple_is_paused = false;
   
   btpad_set_inquiry_state(false);
}

- (IBAction)showSettings
{
   [self pushViewController:[[RASettingsList alloc] initWithModule:apple_core] animated:YES];
}

- (IBAction)showSystemSettings
{
   [self pushViewController:[RASystemSettingsList new] animated:YES];
}

@end

int main(int argc, char *argv[])
{
   @autoreleasepool {
#if defined(HAVE_DEBUG_FILELOG) && (TARGET_IPHONE_SIMULATOR == 0)
      NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
      NSString *documentsDirectory = [paths objectAtIndex:0];
      NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"console_stdout.log"];
      freopen([logPath cStringUsingEncoding:NSASCIIStringEncoding], "a", stdout);
      freopen([logPath cStringUsingEncoding:NSASCIIStringEncoding], "a", stderr);
#endif
      return UIApplicationMain(argc, argv, NSStringFromClass([RApplication class]), NSStringFromClass([RetroArch_iOS class]));
   }
}
