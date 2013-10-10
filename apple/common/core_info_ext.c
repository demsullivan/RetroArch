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

#include "core_info_ext.h"

static core_info_list_t* global_core_list = 0;

void apple_core_info_set_core_path(const char* core_path)
{
   if (global_core_list)
      core_info_list_free(global_core_list);
   
   global_core_list = core_path ? core_info_list_new(core_path) : 0;

   if (!global_core_list)
      RARCH_WARN("No cores were found at %s", core_path ? core_path : "(null");
}

const core_info_list_t* apple_core_info_list_get()
{
   if (!global_core_list)
      RARCH_WARN("apple_core_info_list_get() called before apple_core_info_set_core_path()");

   return global_core_list;
}

const core_info_t* apple_core_info_list_get_by_id(const char* core_id)
{
   if (core_id)
   {
      const core_info_list_t* cores = apple_core_info_list_get();

      for (int i = 0; i != cores->count; i ++)
         if (cores->list[i].path && strcmp(core_id, cores->list[i].path) == 0)
            return &cores->list[i];
   }

   return 0;
}

const char* apple_core_info_get_id(const core_info_t* info, char* buffer, size_t buffer_length)
{
   if (!buffer || !buffer_length)
      return "";

   if (info && info->path && strlcpy(buffer, info->path, buffer_length) < buffer_length)
      return buffer;

   *buffer = 0;
   return buffer;
}

