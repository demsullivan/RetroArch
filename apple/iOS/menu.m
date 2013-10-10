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

#include "apple/common/RetroArch_Apple.h"
#include "menu.h"

/*********************************************/
/* RAMenuBase                                */
/* A menu class that displays RAMenuItemBase */
/* objects.                                  */
/*********************************************/
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
   [[self itemForIndexPath:indexPath] wasSelectedOnTableView:tableView ofController:self];
}

@end

/*********************************************/
/* RAMenuItemBasic                           */
/* A simple menu item that displays a text   */
/* description and calls a block object when */
/* selected.                                 */
/*********************************************/
@implementation RAMenuItemBasic

+ (RAMenuItemBasic*)itemWithDescription:(NSString*)description action:(void (^)())action
{
   return [self itemWithDescription:description action:action detail:Nil];
}

+ (RAMenuItemBasic*)itemWithDescription:(NSString*)description action:(void (^)())action detail:(NSString* (^)())detail
{
   RAMenuItemBasic* item = [RAMenuItemBasic new];
   item.description = description;
   item.action = action;
   item.detail = detail;
   return item;
}

- (UITableViewCell*)cellForTableView:(UITableView*)tableView
{
   static NSString* const cell_id = @"text";
   
   UITableViewCell* result = [tableView dequeueReusableCellWithIdentifier:cell_id];
   if (!result)
      result = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cell_id];
   
   result.textLabel.text = self.description;
   result.detailTextLabel.text = self.detail ? self.detail() : nil;
   return result;
}

- (void)wasSelectedOnTableView:(UITableView*)tableView ofController:(UIViewController*)controller
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
      [(id)result.accessoryView setOn:*self.setting->value.boolean];
   return result;
}

- (void)handleBooleanSwitch:(UISwitch*)swt
{
   if (self.setting)
      *self.setting->value.boolean = swt.on ? true : false;
}

- (void)wasSelectedOnTableView:(UITableView*)tableView ofController:(UIViewController*)controller
{
}

@end

/*********************************************/
/* RAMenuItemString                          */
/* A simple menu item that displays the      */
/* state, and allows editing, of a string or */
/* numeric setting.                          */
/*********************************************/
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

   self.parentTable = tableView;

   UITableViewCell* result = [tableView dequeueReusableCellWithIdentifier:cell_id];
   if (!result)
   {
      result = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cell_id];
      result.selectionStyle = UITableViewCellSelectionStyleNone;
   }

   char buffer[256];
   result.textLabel.text = @(self.setting->short_description);

   if (self.setting)
      result.detailTextLabel.text = @(setting_data_get_string_representation(self.setting, buffer, sizeof(buffer)));
   return result;
}

- (void)wasSelectedOnTableView:(UITableView*)tableView ofController:(UIViewController*)controller
{
   UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Enter new value" message:@(self.setting->short_description) delegate:self
                                                  cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
   alertView.alertViewStyle = UIAlertViewStylePlainTextInput;

   UITextField* field = [alertView textFieldAtIndex:0];
   char buffer[256];
   
   field.delegate = self;
   field.text = @(setting_data_get_string_representation(self.setting, buffer, sizeof(buffer)));
   field.keyboardType = (self.setting->type == ST_INT || self.setting->type == ST_FLOAT) ? UIKeyboardTypeDecimalPad : UIKeyboardTypeDefault;

   [alertView show];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
   if (self.setting->type == ST_INT || self.setting->type == ST_FLOAT)
   {
      RANumberFormatter* formatter = [[RANumberFormatter alloc] initWithFloatSupport:self.setting->type == ST_FLOAT
                                                                minimum:self.setting->min maximum:self.setting->max];

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
      setting_data_set_with_string_representation(self.setting, text.UTF8String);
      [self.parentTable reloadData];
   }
}

@end

/*********************************************/
/* RAMenuItemPathSetting                     */
/* A menu item that displays and allows      */
/* browsing for a path setting.              */
/*********************************************/
@implementation RAMenuItemPathSetting

+ (RAMenuItemPathSetting*)itemForSetting:(const char*)setting_name
{
   RAMenuItemPathSetting* item = [RAMenuItemPathSetting new];
   item.setting = setting_data_find_setting(setting_name);
   return item;
}

- (void)wasSelectedOnTableView:(UITableView*)tableView ofController:(UIViewController*)controller
{
   self.baseList = [[RADirectoryList alloc] initWithPath:@"/" delegate:self];
   [controller.navigationController pushViewController:self.baseList animated:YES];
}

- (bool)directoryList:(id)list itemWasSelected:(RADirectoryItem *)path
{
   if(path.isDirectory)
      [[list navigationController] pushViewController:[[RADirectoryList alloc] initWithPath:path.path delegate:self] animated:YES];
   else
   {
      setting_data_set_with_string_representation(self.setting, path.path.UTF8String);
      [self.baseList.navigationController popToViewController:self.baseList animated:NO];
      [self.baseList.navigationController popViewControllerAnimated:YES];
      
      [self.parentTable reloadData];
   }
   
   return true;
}

@end


/*********************************************/
/* RAMainMenu                                */
/* Menu object that is displayed immediately */
/* after startup.                            */
/*********************************************/
@implementation RAMainMenu

- (id)init
{
   if ((self = [super initWithStyle:UITableViewStylePlain]))
   {
      self.title = @"RetroArch";
   
      self.sections =
      (id)@[
         @[ @"",
            [RAMenuItemBasic itemWithDescription:@"Choose Core"
               action:^{ [self chooseCore];   }
               detail:^{ return self.core ? self.core.description : @"None Selected"; }],
            [RAMenuItemBasic itemWithDescription:@"Load Game (Core)"          action:^{ [self loadGame];     }],
            [RAMenuItemBasic itemWithDescription:@"Load Game (History)"       action:^{ [self loadGame];     }],
            [RAMenuItemBasic itemWithDescription:@"Load Game (Detect Core)"   action:^{ [self loadGame];     }],
            [RAMenuItemBasic itemWithDescription:@"Settings"                  action:^{ [self showSettings]; }]
         ]
      ];
   }
   
   return self;
}

- (void)chooseCore
{
   [self.navigationController pushViewController:[[RAModuleList alloc] initWithGame:@"" delegate:self] animated:YES];
}

- (bool)moduleList:(id)list itemWasSelected:(RAModuleInfo *)module
{
   self.core = module;
   [self.tableView reloadData];
   [self.navigationController popViewControllerAnimated:YES];
   return true;
}

- (void)loadGame
{
   [RetroArch_iOS.get beginBrowsingForFile];
}

- (void)showSettings
{
   [self.navigationController pushViewController:[RAFrontendSettingsMenu new] animated:YES];
}

@end

/*********************************************/
/* RAFronendSettingsMenu                     */
/* Menu object that displays and allows      */
/* editing of cocoa frontend related         */
/* settings.                                 */
/*********************************************/
static const void* const associated_core_key = &associated_core_key;

@implementation RAFrontendSettingsMenu

- (id)init
{
   if ((self = [super initWithStyle:UITableViewStyleGrouped]))
   {
      NSMutableArray* cores = [NSMutableArray arrayWithObject:@"Cores"];
      [cores addObject:[RAMenuItemBasic itemWithDescription:@"Global Core Config"
         action: ^{ [self showCoreConfigFor:nil]; }]];

      NSArray* coreList = apple_get_modules();
      for (RAModuleInfo* i in coreList)
         [cores addObject:[RAMenuItemBasic itemWithDescription:i.description
            action: ^{ [self showCoreConfigFor:i]; }
            detail: ^{ return i.hasCustomConfig ? @"[Custom]" : @"[Global]"; }]];
  
      self.sections =
      (id)@[
         @[ @"Frontend",
            [RAMenuItemBasic itemWithDescription:@"Diagnostic Log"
               action: ^{ [self.navigationController pushViewController:[RALogView new] animated:YES]; }],
            [RAMenuItemBasic itemWithDescription:@"TV Mode" action:^{ }]
         ],
         
         @[ @"Bluetooth",
            [RAMenuItemBasic itemWithDescription:@"Mode" action:^{ }]
         ],
         
         @[ @"Orientations",
            [RAMenuItemBasic itemWithDescription:@"Portrait" action:^{ }],
            [RAMenuItemBasic itemWithDescription:@"Portrait Upside Down" action:^{ }],
            [RAMenuItemBasic itemWithDescription:@"Landscape Left" action:^{ }],
            [RAMenuItemBasic itemWithDescription:@"Landscape Right" action:^{ }]
         ],
         
         cores
      ];
   }
   
   return self;
}

- (void)showCoreConfigFor:(RAModuleInfo*)core
{
   if (core && !core.hasCustomConfig)
   {
      UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"RetroArch"
                                                      message:@"No custom configuration for this core exists, "
                                                               "would you like to create one?"
                                                     delegate:self
                                            cancelButtonTitle:@"No"
                                            otherButtonTitles:@"Yes", nil];
      objc_setAssociatedObject(alert, associated_core_key, core, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      [alert show];
   }
   else
      [self.navigationController pushViewController:[[RACoreSettingsMenu alloc] initWithCore:core] animated:YES];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
   RAModuleInfo* core = objc_getAssociatedObject(alertView, associated_core_key);
      
   if (buttonIndex == alertView.firstOtherButtonIndex && core)
   {
      [core createCustomConfig];
      [self.tableView reloadData];
   }
   
   [self.navigationController pushViewController:[[RACoreSettingsMenu alloc] initWithCore:core] animated:YES];
}

@end

/*********************************************/
/* RACoreSettingsMenu                        */
/* Menu object that displays and allows      */
/* editing of the setting_data list.         */
/*********************************************/
@implementation RACoreSettingsMenu

- (id)initWithCore:(RAModuleInfo*)core
{
   if ((self = [super initWithStyle:UITableViewStyleGrouped]))
   {
      setting_data_reset();
      
      self.core = core;
      self.title = self.core ? self.core.description : @"Global Core Settings";
   
      NSMutableArray* settings = [NSMutableArray arrayWithObjects:@"", nil];
      [self.sections addObject:settings];
      
      const rarch_setting_t* setting_data = setting_data_get_list();
      for (const rarch_setting_t* i = setting_data; i->type != ST_NONE; i ++)
         if (i->type == ST_GROUP)
            [settings addObject:[RAMenuItemBasic itemWithDescription:@(i->name) action:
            ^{
               [self.navigationController pushViewController:[[RACoreSettingsMenu alloc] initWithGroup:i] animated:YES];
            }]];
   }
   
   return self;
}

- (id)initWithGroup:(const rarch_setting_t*)group
{
   if ((self = [super initWithStyle:UITableViewStyleGrouped]))
   {
      self.title = @(group->name);
   
      NSMutableArray* settings = nil;
   
      for (const rarch_setting_t* i = group + 1; i->type != ST_END_GROUP; i ++)
      {
         if (i->type == ST_SUB_GROUP)
            settings = [NSMutableArray arrayWithObjects:@(i->name), nil];
         else if (i->type == ST_END_SUB_GROUP)
         {
            if (settings.count)
               [self.sections addObject:settings];
         }
         else if (i->type == ST_BOOL)
            [settings addObject:[RAMenuItemBoolean itemForSetting:i->name]];
         else if (i->type == ST_INT || i->type == ST_FLOAT || i->type == ST_STRING)
            [settings addObject:[RAMenuItemString itemForSetting:i->name]];
         else if (i->type == ST_PATH)
            [settings addObject:[RAMenuItemPathSetting itemForSetting:i->name]];
      }
   }

   return self;
}

@end
