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
      [(id)result.accessoryView setOn:*(bool*)self.setting];
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
      @[
         @[
            @"",
            [RAMenuItemBasic itemWithDescription:@"Choose Core"               action:^{ [self chooseCore];   }],
            [RAMenuItemBasic itemWithDescription:@"Load Game (Core)"          action:^{ [self loadGame];     }],
            [RAMenuItemBasic itemWithDescription:@"Load Game (History)"       action:^{ [self loadGame];     }],
            [RAMenuItemBasic itemWithDescription:@"Load Game (Detect Core)"   action:^{ [self loadGame];     }],
            [RAMenuItemBasic itemWithDescription:@"Settings"                  action:^{ [self showSettings]; }],
            [RAMenuItemBoolean itemForSetting:"video_fullscreen"],
            [RAMenuItemString itemForSetting:"audio_device"],
            [RAMenuItemString itemForSetting:"video_monitor_index"],
            [RAMenuItemPathSetting itemForSetting:"libretro_path"]
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
   printf("%s\n", module.path.UTF8String);
   [self.navigationController popViewControllerAnimated:YES];
   return true;
}

- (void)loadGame
{
   [RetroArch_iOS.get beginBrowsingForFile];
}

- (void)showSettings
{
   [self.navigationController pushViewController:[RASystemSettingsList new] animated:YES];
}

@end
