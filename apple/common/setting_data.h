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

#ifndef __APPLE_RARCH_SETTING_DATA_H__
#define __APPLE_RARCH_SETTING_DATA_H__

#include "general.h"

enum setting_type { ST_NONE, ST_BOOL, ST_INT, ST_FLOAT, ST_PATH, ST_STRING, ST_HEX, ST_BIND,
                    ST_GROUP, ST_SUB_GROUP, ST_END_GROUP, ST_END_SUB_GROUP };

typedef struct
{
   enum setting_type type;

   const char* name;
   
   void* value;
   uint32_t size;
   
   const char* short_description;

   uint32_t index;

   double min;
   double max;
   bool allow_blank;
}  rarch_setting_t;

#define BINDFOR(s) (*(struct retro_keybind*)(&s)->value)

extern const rarch_setting_t setting_data[];

void setting_data_reset();
void setting_data_load_current();

bool setting_data_load_config_path(const char* path);
bool setting_data_load_config(config_file_t* config);
bool setting_data_save_config_path(const char* path);
bool setting_data_save_config(config_file_t* config);

const char* setting_data_get_string_representation(const rarch_setting_t* setting, char* buffer, size_t length);

// Keyboard
#include "keycode.h"

#endif