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

#include <sys/stat.h>

#include "RetroArch_Apple.h"

#include "general.h"
#include "file.h"

void apple_display_alert(NSString* message, NSString* title)
{
#ifdef IOS
   UIAlertView* alert = [[UIAlertView alloc] initWithTitle:title ? title : @"RetroArch"
                                             message:message
                                             delegate:nil
                                             cancelButtonTitle:@"OK"
                                             otherButtonTitles:nil];
   [alert show];
#else
   NSAlert* alert = [NSAlert new];
   alert.messageText = title ? title : @"RetroArch";
   alert.informativeText = message;
   alert.alertStyle = NSInformationalAlertStyle;
   [alert beginSheetModalForWindow:RetroArch_OSX.get->window
          modalDelegate:apple_platform
          didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
          contextInfo:nil];
   [NSApplication.sharedApplication runModalForWindow:alert.window];
#endif
}

// Little nudge to prevent stale values when reloading the confg file
void objc_clear_config_hack()
{
   g_extern.block_config_read = false;
   memset(g_settings.input.overlay, 0, sizeof(g_settings.input.overlay));
   memset(g_settings.video.shader_path, 0, sizeof(g_settings.video.shader_path));
}

// Fetch a value from a config file, returning defaultValue if the value is not present
NSString* objc_get_value_from_config(config_file_t* config, NSString* name, NSString* defaultValue)
{
   char* data = 0;
   if (config)
      config_get_string(config, [name UTF8String], &data);
   
   NSString* result = data ? @(data) : defaultValue;
   free(data);
   return result;
}

// Ensures a directory exists and has correct permissions
bool path_make_and_check_directory(const char* path, mode_t mode, int amode)
{
   if (!path_is_directory(path) && mkdir(path, mode) != 0)
      return false;
   
   return access(path, amode) == 0;
}

// Get a core id as an NSString
NSString* apple_get_core_id(const core_info_t* core)
{
   char buf[PATH_MAX];
   return @(apple_core_info_get_id(core, buf, sizeof(buf)));
}

NSString* apple_get_core_display_name(NSString* core_id)
{
   const core_info_t* core = apple_core_info_list_get_by_id(core_id.UTF8String);
   return core ? @(core->display_name) : core_id;
}

// Number formatter class for setting strings
@implementation RANumberFormatter
- (id)initWithFloatSupport:(bool)allowFloat minimum:(double)min maximum:(double)max
{
   self = [super init];
   self.allowsFloats = allowFloat;
   self.maximumFractionDigits = 10;
   
   if (min || max)
   {
      self.minimum = @(min);
      self.maximum = @(max);
   }
   
   return self;
}

- (BOOL)isPartialStringValid:(NSString*)partialString newEditingString:(NSString**)newString errorDescription:(NSString**)error
{
   bool hasDot = false;

   if (partialString.length)
      for (int i = 0; i != partialString.length; i ++)
      {
         unichar ch = [partialString characterAtIndex:i];
         
         if (i == 0 && (!self.minimum || self.minimum.intValue < 0) && ch == '-')
            continue;
         else if (self.allowsFloats && !hasDot && ch == '.')
            hasDot = true;
         else if (!isdigit(ch))
            return NO;
      }

   return YES;
}
@end


#ifdef IOS

char* ios_get_rarch_system_directory()
{
   return strdup([RetroArch_iOS.get.systemDirectory UTF8String]);
}

#include "../iOS/views.h"

// Simple class to reduce code duplication for fixed table views
@implementation RATableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
   self = [super initWithStyle:style];
   self.sections = [NSMutableArray array];
   return self;
}

- (bool)getCellFor:(NSString*)reuseID withStyle:(UITableViewCellStyle)style result:(UITableViewCell**)output
{
   UITableViewCell* result = [self.tableView dequeueReusableCellWithIdentifier:reuseID];
   
   if (result)
      *output = result;
   else
      *output = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:reuseID];
   
   return !result;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView
{
   return self.sections.count;
}

- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section
{
   return self.hidesHeaders ? nil : self.sections[section][0];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
   return [self.sections[section] count] - 1;
}

- (id)itemForIndexPath:(NSIndexPath*)indexPath
{
   return self.sections[indexPath.section][indexPath.row + 1];
}

- (void)reset
{
   self.sections = [NSMutableArray array];
   [self.tableView reloadData];
}
@end

#endif
