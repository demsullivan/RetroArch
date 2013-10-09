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

#include "setting_data.h"

// Input
static const char* get_input_config_key(const rarch_setting_t* setting, const char* type)
{
   static char buffer[32];
   if (setting->index)
      snprintf(buffer, 32, "input_player%d_%s%c%s", setting->index, setting->name, type ? '_' : '\0', type);
   else
      snprintf(buffer, 32, "input_%s%c%s", setting->name, type ? '_' : '\0', type);
   return buffer;
}

static const char* get_key_name(const rarch_setting_t* setting)
{
   if (BINDFOR(*setting).key == RETROK_UNKNOWN)
      return "nul";

   uint32_t hidkey = input_translate_rk_to_keysym(BINDFOR(*setting).key);
   
   for (int i = 0; apple_key_name_map[i].hid_id; i ++)
      if (apple_key_name_map[i].hid_id == hidkey)
         return apple_key_name_map[i].keyname;
   
   return "nul";
}


static const char* get_button_name(const rarch_setting_t* setting)
{
   static char buffer[32];

   if (BINDFOR(*setting).joykey == NO_BTN)
      return "nul";

   snprintf(buffer, 32, "%lld", BINDFOR(*setting).joykey);
   return buffer;
}

static const char* get_axis_name(const rarch_setting_t* setting)
{
   static char buffer[32];
   
   uint32_t joyaxis = BINDFOR(*setting).joyaxis;
   
   if (AXIS_NEG_GET(joyaxis) != AXIS_DIR_NONE)
      snprintf(buffer, 8, "-%d", AXIS_NEG_GET(joyaxis));
   else if (AXIS_POS_GET(joyaxis) != AXIS_DIR_NONE)
      snprintf(buffer, 8, "+%d", AXIS_POS_GET(joyaxis));
   else
      return "nul";
   
   return buffer;
}


// HACK
struct settings fake_settings;
struct global fake_extern;

// Can't put this below the defines that follow it
void setting_data_load_current()
{
   // TODO: Load defaults

   memcpy(&fake_settings, &g_settings, sizeof(struct settings));
   memcpy(&fake_extern, &g_extern, sizeof(struct global));
}

#define g_settings fake_settings
#define g_extern fake_extern

void setting_data_reset()
{
   memset(&g_settings, 0, sizeof(g_settings));
   memset(&g_extern, 0, sizeof(g_extern));
}

bool setting_data_load_config_path(const char* path)
{
   config_file_t* config = config_file_new(path);
   
   if (config)
   {
      setting_data_load_config(config);
      config_file_free(config);
   }
   
   return config;
}

bool setting_data_load_config(config_file_t* config)
{
   if (!config)
      return false;
   
   for (int i = 0; setting_data[i].type; i ++)
   {
      switch (setting_data[i].type)
      {
         case ST_BOOL:   config_get_bool  (config, setting_data[i].name,  (bool*)setting_data[i].value); break;
         case ST_INT:    config_get_int   (config, setting_data[i].name,   (int*)setting_data[i].value); break;
         case ST_FLOAT:  config_get_float (config, setting_data[i].name, (float*)setting_data[i].value); break;
         case ST_PATH:   config_get_array (config, setting_data[i].name,  (char*)setting_data[i].value, setting_data[i].size); break;
         case ST_STRING: config_get_array (config, setting_data[i].name,  (char*)setting_data[i].value, setting_data[i].size); break;
         
         case ST_BIND:
         {
            input_config_parse_key       (config, "input_player1", setting_data[i].name, setting_data[i].value);
            input_config_parse_joy_button(config, "input_player1", setting_data[i].name, setting_data[i].value);
            input_config_parse_joy_axis  (config, "input_player1", setting_data[i].name, setting_data[i].value);
            break;
         }
         
         case ST_HEX:    break;
         default:        break;
      }
   }
   
   return true;
}


bool setting_data_save_config_path(const char* path)
{
   config_file_t* config = config_file_new(path);
   
   if (!config)
      config = config_file_new(0);
   
   setting_data_save_config(config);
   bool result = config_file_write(config, path);
   config_file_free(config);
   
   return result;
}

bool setting_data_save_config(config_file_t* config)
{
   if (!config)
      return false;
   
   for (int i = 0; setting_data[i].type; i ++)
   {
      switch (setting_data[i].type)
      {
         case ST_BOOL:   config_set_bool  (config, setting_data[i].name, * (bool*)setting_data[i].value); break;
         case ST_INT:    config_set_int   (config, setting_data[i].name, *  (int*)setting_data[i].value); break;
         case ST_FLOAT:  config_set_float (config, setting_data[i].name, *(float*)setting_data[i].value); break;
         case ST_PATH:   config_set_string(config, setting_data[i].name,   (char*)setting_data[i].value); break;
         case ST_STRING: config_set_string(config, setting_data[i].name,   (char*)setting_data[i].value); break;
         
         case ST_BIND:
         {
            config_set_string(config, get_input_config_key(&setting_data[i], 0     ), get_key_name(&setting_data[i]));
            config_set_string(config, get_input_config_key(&setting_data[i], "btn" ), get_button_name(&setting_data[i]));
            config_set_string(config, get_input_config_key(&setting_data[i], "axis"), get_axis_name(&setting_data[i]));
            break;
         }
         
         case ST_HEX:    break;
         default:        break;
      }
   }
   
   return true;
}

const rarch_setting_t* setting_data_find_setting(const char* name)
{
   if (!name)
      return 0;

   for (const rarch_setting_t* i = setting_data; i->type != ST_NONE; i ++)
      if (i->type <= ST_GROUP && strcmp(i->name, name) == 0)
         return i;

   return 0;
}

void setting_data_set_with_string_representation(const rarch_setting_t* setting, const char* value)
{
   if (!setting || !value)
      return;
   
   switch (setting->type)
   {
      case ST_INT:    sscanf(value, "%d", (  int*)setting->value); break;
      case ST_FLOAT:  sscanf(value, "%f", (float*)setting->value); break;
      case ST_PATH:   strlcpy((char*)setting->value, value, setting->size); break;
      case ST_STRING: strlcpy((char*)setting->value, value, setting->size); break;
      
      default: return;
   }
}

const char* setting_data_get_string_representation(const rarch_setting_t* setting, char* buffer, size_t length)
{
   if (!setting || !buffer || !length)
      return "";

   switch (setting->type)
   {
      case ST_BOOL:   snprintf(buffer, length, "%s", *( bool*)setting->value ? "True" : "False"); break;
      case ST_INT:    snprintf(buffer, length, "%d", *(  int*)setting->value); break;
      case ST_FLOAT:  snprintf(buffer, length, "%f", *(float*)setting->value); break;
      case ST_PATH:   strlcpy(buffer, (char*)setting->value, length); break;
      case ST_STRING: strlcpy(buffer, (char*)setting->value, length); break;

      case ST_BIND:
      {
         snprintf(buffer, length, "[KB:%s] [JS:%s] [AX:%s]", get_key_name(setting), get_button_name(setting), get_axis_name(setting));
         break;
      }

      default: return "";
   }

   return buffer;
}

#define START_GROUP(NAME)                  { ST_GROUP,         NAME },
#define END_GROUP()                        { ST_END_GROUP },
#define START_SUB_GROUP(NAME)              { ST_SUB_GROUP,     NAME },
#define END_SUB_GROUP()                    { ST_END_SUB_GROUP },
#define CONFIG_BOOL(TARGET, NAME, SHORT)   { ST_BOOL,          NAME, &TARGET, sizeof(TARGET), SHORT },
#define CONFIG_INT(TARGET, NAME, SHORT)    { ST_INT,           NAME, &TARGET, sizeof(TARGET), SHORT },
#define CONFIG_FLOAT(TARGET, NAME, SHORT)  { ST_FLOAT,         NAME, &TARGET, sizeof(TARGET), SHORT },
#define CONFIG_PATH(TARGET, NAME, SHORT)   { ST_PATH,          NAME, &TARGET, sizeof(TARGET), SHORT },
#define CONFIG_STRING(TARGET, NAME, SHORT) { ST_STRING,        NAME, &TARGET, sizeof(TARGET), SHORT },
#define CONFIG_HEX(TARGET, NAME, SHORT)    { ST_HEX,           NAME, &TARGET, sizeof(TARGET), SHORT },

#define CONFIG_BIND(TARGET, PLAYER, NAME, SHORT)   { ST_BIND,          NAME, &TARGET, sizeof(TARGET), SHORT, PLAYER },

const rarch_setting_t setting_data[] = 
{
   /***********/
   /* DRIVERS */
   /***********/
#if 0
   START_GROUP("Drivers")
      START_SUB_GROUP("Drivers")
         CONFIG_STRING(g_settings.video.driver, "video_driver", "Video Driver")
         CONFIG_STRING(g_settings.video.gl_context, "video_gl_context", "OpenGL Driver")
         CONFIG_STRING(g_settings.audio.driver, "audio_driver", "Audio Driver")
         CONFIG_STRING(g_settings.input.driver, "input_driver", "Input Driver")
         CONFIG_STRING(g_settings.input.joypad_driver, "input_joypad_driver", "Joypad Driver")
      END_SUB_GROUP()
   END_GROUP()
#endif

   /*********/
   /* PATHS */
   /*********/
   START_GROUP("Paths")
      START_SUB_GROUP("Paths")
         CONFIG_PATH(g_settings.libretro, "libretro_path", "libretro Path")
         CONFIG_PATH(g_settings.core_options_path, "core_options_path", "Core Options Path")
         CONFIG_PATH(g_settings.screenshot_directory, "screenshot_directory", "Screenshot Directory")
         CONFIG_PATH(g_settings.cheat_database, "cheat_database_path", "Cheat Database")
         CONFIG_PATH(g_settings.cheat_settings_path, "cheat_settings_path", "Cheat Settings")
         CONFIG_PATH(g_settings.game_history_path, "game_history_path", "Game History Path")
         CONFIG_INT(g_settings.game_history_size, "game_history_size", "Game History Size")

         #ifdef HAVE_RGUI
            CONFIG_PATH(g_settings.rgui_browser_directory, "rgui_browser_directory", "Browser Directory")
         #endif

         #ifdef HAVE_OVERLAY
            CONFIG_PATH(g_extern.overlay_dir, "overlay_directory", "Overlay Directory")
         #endif
      END_SUB_GROUP()
   END_GROUP()


   /*************/
   /* EMULATION */
   /*************/
   START_GROUP("Emulation")
      START_SUB_GROUP("Emulation")
         CONFIG_BOOL(g_settings.pause_nonactive, "pause_nonactive", "Pause when inactive")
         CONFIG_BOOL(g_settings.rewind_enable, "rewind_enable", "Enable Rewind")
         CONFIG_INT(g_settings.rewind_buffer_size, "rewind_buffer_size", "Rewind Buffer Size") /* *= 1000000 */
         CONFIG_INT(g_settings.rewind_granularity, "rewind_granularity", "Rewind Granularity")
         CONFIG_FLOAT(g_settings.slowmotion_ratio, "slowmotion_ratio", "Slow motion ratio") /* >= 1.0f */

         /* Saves */
         CONFIG_INT(g_settings.autosave_interval, "autosave_interval", "Autosave Interval")
         CONFIG_BOOL(g_settings.block_sram_overwrite, "block_sram_overwrite", "Block SRAM overwrite")
         CONFIG_BOOL(g_settings.savestate_auto_index, "savestate_auto_index", "Save State Auto Index")
         CONFIG_BOOL(g_settings.savestate_auto_save, "savestate_auto_save", "Auto Save State")
         CONFIG_BOOL(g_settings.savestate_auto_load, "savestate_auto_load", "Auto Load State")
      END_SUB_GROUP()
   END_GROUP()

   /*********/
   /* VIDEO */
   /*********/
   START_GROUP("Video")
      START_SUB_GROUP("Monitor")
         CONFIG_INT(g_settings.video.monitor_index, "video_monitor_index", "Monitor Index")
         CONFIG_BOOL(g_settings.video.fullscreen, "video_fullscreen", "Use Fullscreen mode") // if (!g_extern.force_fullscreen)
         CONFIG_BOOL(g_settings.video.windowed_fullscreen, "video_windowed_fullscreen", "Windowed Fullscreen Mode")
         CONFIG_INT(g_settings.video.fullscreen_x, "video_fullscreen_x", "Fullscreen Width")
         CONFIG_INT(g_settings.video.fullscreen_y, "video_fullscreen_y", "Fullscreen Height")
         CONFIG_FLOAT(g_settings.video.refresh_rate, "video_refresh_rate", "Refresh Rate")
      END_SUB_GROUP()

#if 0
      /* Video: Window Manager */
      START_SUB_GROUP("Window Manager")
         CONFIG_BOOL(g_settings.video.disable_composition, "video_disable_composition", "Disable WM Composition")
      END_SUB_GROUP()
#endif

      START_SUB_GROUP("Aspect")
         CONFIG_BOOL(g_settings.video.force_aspect, "video_force_aspect", "Force aspect ratio")
         CONFIG_FLOAT(g_settings.video.aspect_ratio, "video_aspect_ratio", "Aspect Ratio")
         CONFIG_BOOL(g_settings.video.aspect_ratio_auto, "video_aspect_ratio_auto", "Use Auto Aspect Ratio")
         CONFIG_INT(g_settings.video.aspect_ratio_idx, "aspect_ratio_index", "Aspect Ratio Index")
      END_SUB_GROUP()

      START_SUB_GROUP("Scaling")
         CONFIG_FLOAT(g_settings.video.xscale, "video_xscale", "X Scale")
         CONFIG_FLOAT(g_settings.video.yscale, "video_yscale", "Y Scale")
         CONFIG_BOOL(g_settings.video.scale_integer, "video_scale_integer", "Force integer scaling")

         CONFIG_INT(g_extern.console.screen.viewports.custom_vp.x, "custom_viewport_x", "Custom Viewport X")
         CONFIG_INT(g_extern.console.screen.viewports.custom_vp.y, "custom_viewport_y", "Custom Viewport Y")
         CONFIG_INT(g_extern.console.screen.viewports.custom_vp.width, "custom_viewport_width", "Custom Viewport Width")
         CONFIG_INT(g_extern.console.screen.viewports.custom_vp.height, "custom_viewport_height", "Custom Viewport Height")

         CONFIG_BOOL(g_settings.video.smooth, "video_smooth", "Use bilinear filtering")
      END_SUB_GROUP()

      START_SUB_GROUP("Shader")
         CONFIG_BOOL(g_settings.video.shader_enable, "video_shader_enable", "Enable Shaders")
         CONFIG_PATH(g_settings.video.shader_dir, "video_shader_dir", "Shader Directory")
         CONFIG_PATH(g_settings.video.shader_path, "video_shader", "Shader")
      END_SUB_GROUP()

      START_SUB_GROUP("Sync")
         CONFIG_BOOL(g_settings.video.threaded, "video_threaded", "Use threaded video")
         CONFIG_BOOL(g_settings.video.vsync, "video_vsync", "Use VSync")
         CONFIG_BOOL(g_settings.video.hard_sync, "video_hard_sync", "Use OpenGL Hard Sync")
         CONFIG_INT(g_settings.video.hard_sync_frames, "video_hard_sync_frames", "Number of Hard Sync frames") // 0 - 3
      END_SUB_GROUP()

      START_SUB_GROUP("Misc")
         CONFIG_BOOL(g_settings.video.post_filter_record, "video_post_filter_record", "Post filter record")
         CONFIG_BOOL(g_settings.video.gpu_record, "video_gpu_record", "GPU Record")
         CONFIG_BOOL(g_settings.video.gpu_screenshot, "video_gpu_screenshot", "GPU Screenshot")
         CONFIG_BOOL(g_settings.video.allow_rotate, "video_allow_rotate", "Allow rotation")
         CONFIG_BOOL(g_settings.video.crop_overscan, "video_crop_overscan", "Crop Overscan")

         #ifdef HAVE_DYLIB
            CONFIG_PATH(g_settings.video.filter_path, "video_filter", "Software filter"),
         #endif
      END_SUB_GROUP()

      START_SUB_GROUP("Messages")
         CONFIG_PATH(g_settings.video.font_path, "video_font_path", "Font Path")
         CONFIG_FLOAT(g_settings.video.font_size, "video_font_size", "Font Size")
         CONFIG_BOOL(g_settings.video.font_enable, "video_font_enable", "Font Enable")
         CONFIG_BOOL(g_settings.video.font_scale, "video_font_scale", "Font Scale")
         CONFIG_FLOAT(g_settings.video.msg_pos_x, "video_message_pos_x", "Message X Position")
         CONFIG_FLOAT(g_settings.video.msg_pos_y, "video_message_pos_y", "Message Y Position")
         /* message color */
      END_SUB_GROUP()
   END_GROUP()

   /*********/
   /* AUDIO */
   /*********/
   START_GROUP("Audio")
      START_SUB_GROUP("Audio")
         CONFIG_BOOL(g_settings.audio.enable, "audio_enable", "Enable")
         CONFIG_FLOAT(g_settings.audio.volume, "audio_volume", "Volume")

         /* Audio: Sync */
         CONFIG_BOOL(g_settings.audio.sync, "audio_sync", "Enable Sync")
         CONFIG_INT(g_settings.audio.latency, "audio_latency", "Latency")
         CONFIG_BOOL(g_settings.audio.rate_control, "audio_rate_control", "Enable Rate Control")
         CONFIG_FLOAT(g_settings.audio.rate_control_delta, "audio_rate_control_delta", "Rate Control Delta")

         /* Audio: Other */
         CONFIG_STRING(g_settings.audio.device, "audio_device", "Device")
         CONFIG_INT(g_settings.audio.out_rate, "audio_out_rate", "Ouput Rate")
         CONFIG_PATH(g_settings.audio.dsp_plugin, "audio_dsp_plugin", "DSP Plugin")
      END_SUB_GROUP()
   END_GROUP()

   /*********/
   /* INPUT */
   /*********/
   START_GROUP("Input")
      START_SUB_GROUP("Input")
         /* Input: Autoconfig */
         CONFIG_BOOL(g_settings.input.autodetect_enable, "input_autodetect_enable", "Use joypad autodetection")
         CONFIG_PATH(g_settings.input.autoconfig_dir, "joypad_autoconfig_dir", "Joypad Autoconfig Directory")

         /* Input: Joypad mapping */
         CONFIG_INT(g_settings.input.joypad_map[0], "input_player1_joypad_index", "Player 1 Pad Index")
         CONFIG_INT(g_settings.input.joypad_map[1], "input_player2_joypad_index", "Player 2 Pad Index")
         CONFIG_INT(g_settings.input.joypad_map[2], "input_player3_joypad_index", "Player 3 Pad Index")
         CONFIG_INT(g_settings.input.joypad_map[3], "input_player4_joypad_index", "Player 4 Pad Index")
         CONFIG_INT(g_settings.input.joypad_map[4], "input_player5_joypad_index", "Player 5 Pad Index")

         /* Input: Turbo/Axis options */
         CONFIG_FLOAT(g_settings.input.axis_threshold, "input_axis_threshold", "Axis Deadzone")
         CONFIG_INT(g_settings.input.turbo_period, "input_turbo_period", "Turbo Period")
         CONFIG_INT(g_settings.input.turbo_duty_cycle, "input_duty_cycle", "Duty Cycle")

         /* Input: Misc */
         CONFIG_BOOL(g_settings.input.netplay_client_swap_input, "netplay_client_swap_input", "Swap Netplay Input")
         CONFIG_BOOL(g_settings.input.debug_enable, "input_debug_enable", "Enable Input Debugging")

         /* Input: Overlay */
         #ifdef HAVE_OVERLAY
            CONFIG_PATH(g_settings.input.overlay, "input_overlay", "Input Overlay")
            CONFIG_FLOAT(g_settings.input.overlay_opacity, "input_overlay_opacity", "Overlay Opacity")
            CONFIG_FLOAT(g_settings.input.overlay_scale, "input_overlay_scale", "Overlay Scale")
         #endif

         /* Input: Android */
         #ifdef ANDROID
            CONFIG_INT(g_settings.input.back_behavior, "input_back_behavior", "Back Behavior")
            CONFIG_INT(g_settings.input.icade_profile[0], "input_autodetect_icade_profile_pad1", "iCade 1")
            CONFIG_INT(g_settings.input.icade_profile[1], "input_autodetect_icade_profile_pad2", "iCade 2")
            CONFIG_INT(g_settings.input.icade_profile[2], "input_autodetect_icade_profile_pad3", "iCade 3")
            CONFIG_INT(g_settings.input.icade_profile[3], "input_autodetect_icade_profile_pad4", "iCade 4")
         #endif
      END_SUB_GROUP()

      START_SUB_GROUP("Meta Keys")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_FAST_FORWARD_KEY],       0, "toggle_fast_forward",  "Fast forward toggle")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_FAST_FORWARD_HOLD_KEY],  0, "hold_fast_forward",    "Fast forward hold")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_LOAD_STATE_KEY],         0, "load_state",           "Load state")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_SAVE_STATE_KEY],         0, "save_state",           "Save state")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_FULLSCREEN_TOGGLE_KEY],  0, "toggle_fullscreen",    "Fullscreen toggle")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_QUIT_KEY],               0, "exit_emulator",        "Quit RetroArch")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_STATE_SLOT_PLUS],        0, "state_slot_increase",  "Savestate slot +")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_STATE_SLOT_MINUS],       0, "state_slot_decrease",  "Savestate slot -")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_REWIND],                 0, "rewind",               "Rewind")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_MOVIE_RECORD_TOGGLE],    0, "movie_record_toggle",  "Movie record toggle")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_PAUSE_TOGGLE],           0, "pause_toggle",         "Pause toggle")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_FRAMEADVANCE],           0, "frame_advance",        "Frameadvance")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_RESET],                  0, "reset",                "Reset game")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_SHADER_NEXT],            0, "shader_next",          "Next shader")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_SHADER_PREV],            0, "shader_prev",          "Previous shader")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_CHEAT_INDEX_PLUS],       0, "cheat_index_plus",     "Cheat index +")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_CHEAT_INDEX_MINUS],      0, "cheat_index_minus",    "Cheat index -")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_CHEAT_TOGGLE],           0, "cheat_toggle",         "Cheat toggle")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_SCREENSHOT],             0, "screenshot",           "Take screenshot")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_DSP_CONFIG],             0, "dsp_config",           "DSP config")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_MUTE],                   0, "audio_mute",           "Audio mute toggle")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_NETPLAY_FLIP],           0, "netplay_flip_players", "Netplay flip players")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_SLOWMOTION],             0, "slowmotion",           "Slow motion")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_ENABLE_HOTKEY],          0, "enable_hotkey",        "Enable hotkeys")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_VOLUME_UP],              0, "volume_up",            "Volume +")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_VOLUME_DOWN],            0, "volume_down",          "Volume -")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_OVERLAY_NEXT],           0, "overlay_next",         "Overlay next")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_DISK_EJECT_TOGGLE],      0, "disk_eject_toggle",    "Disk eject toggle")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_DISK_NEXT],              0, "disk_next",            "Disk next")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_GRAB_MOUSE_TOGGLE],      0, "grab_mouse_toggle",    "Grab mouse toggle")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_MENU_TOGGLE],            0, "menu_toggle",          "RGUI menu toggle")
      END_SUB_GROUP()

      START_SUB_GROUP("Player 1")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_UP],    1, "up",                   "Up D-pad")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_DOWN],  1, "down",                 "Down D-pad")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_LEFT],  1, "left",                 "Left D-pad")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_RIGHT], 1, "right",                "Right D-pad")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_SELECT],1, "select",               "Select button")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_START], 1, "start",                "Start button")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_B],     1, "b",                    "B button (down)")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_A],     1, "a",                    "A button (right)")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_X],     1, "x",                    "X button (top)")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_Y],     1, "y",                    "Y button (left)")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_L],     1, "l",                    "L button (left shoulder)")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_R],     1, "r",                    "R button (right shoulder)")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_L2],    1, "l2",                   "L2 button (left shoulder #2)")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_R2],    1, "r2",                   "R2 button (right shoulder #2)")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_L3],    1, "l3",                   "L3 button (left analog button)")
         CONFIG_BIND(g_settings.input.binds[0][RETRO_DEVICE_ID_JOYPAD_R3],    1, "r3",                   "R3 button (right analog button)")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_ANALOG_LEFT_Y_MINUS],    1, "l_y_minus",            "Left analog Y- (up)")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_ANALOG_LEFT_Y_PLUS],     1, "l_y_plus",             "Left analog Y+ (down)")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_ANALOG_LEFT_X_MINUS],    1, "l_x_minus",            "Left analog X- (left)")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_ANALOG_LEFT_X_PLUS],     1, "l_x_plus",             "Left analog X+ (right)")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_ANALOG_RIGHT_Y_MINUS],   1, "r_y_minus",            "Right analog Y- (up)")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_ANALOG_RIGHT_Y_PLUS],    1, "r_y_plus",             "Right analog Y+ (down)")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_ANALOG_RIGHT_X_MINUS],   1, "r_x_minus",            "Right analog X- (left)")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_ANALOG_RIGHT_X_PLUS],    1, "r_x_plus",             "Right analog X+ (right)")
         CONFIG_BIND(g_settings.input.binds[0][RARCH_TURBO_ENABLE],           1, "turbo",                "Turbo enable")
      END_SUB_GROUP()
   END_GROUP()

   /********/
   /* Misc */
   /********/
   START_GROUP("Misc")
      START_SUB_GROUP("Misc")
         CONFIG_BOOL(g_extern.config_save_on_exit, "config_save_on_exit", "Save Config On Exit")
         CONFIG_BOOL(g_settings.network_cmd_enable, "network_cmd_enable", "Network Commands")
         CONFIG_INT(g_settings.network_cmd_port, "network_cmd_port", "Network Command Port")
         CONFIG_BOOL(g_settings.stdin_cmd_enable, "stdin_cmd_enable", "stdin command")
      END_SUB_GROUP()
   END_GROUP()

   { 0 }
};

