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

#ifndef _RARCH_APPLE_VIEWS_H
#define _RARCH_APPLE_VIEWS_H

#include <UIKit/UIKit.h>
#include "core_info.h"

// RALogView.m
@interface RALogView : UITableViewController
@end

// utility.m
@interface RATableViewController : UITableViewController
@property (nonatomic) NSMutableArray* sections;
@property (nonatomic) BOOL hidesHeaders;

- (id)initWithStyle:(UITableViewStyle)style;
- (bool)getCellFor:(NSString*)reuseID withStyle:(UITableViewCellStyle)style result:(UITableViewCell**)output;
- (id)itemForIndexPath:(NSIndexPath*)indexPath;
- (void)reset;
@end

// browser.m
@interface RADirectoryItem : NSObject
@property (nonatomic) NSString* path;
@property (nonatomic) bool isDirectory;
@end

// browser.m
@protocol RADirectoryListDelegate
- (bool)directoryList:(id)list itemWasSelected:(RADirectoryItem*)path;
@end

@interface RADirectoryList : RATableViewController <UIActionSheetDelegate>
@property (nonatomic, weak) id<RADirectoryListDelegate> directoryDelegate;
@property (nonatomic, weak) RADirectoryItem* selectedItem;
- (id)initWithPath:(NSString*)path delegate:(id<RADirectoryListDelegate>)delegate;
@end

// browser.m
@protocol RACoreListDelegate
- (bool)coreList:(id)list itemWasSelected:(NSString*)core;
@end

@interface RACoreList : RATableViewController
@property (nonatomic, weak) id<RACoreListDelegate> coreDelegate;
- (id)initWithGame:(NSString*)path delegate:(id<RACoreListDelegate>)delegate;
@end

// browser.m
@interface RAFoldersList : RATableViewController
- (id) initWithFilePath:(NSString*)path;
@end

#endif
