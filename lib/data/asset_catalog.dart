/// Paths to every bundled image and sound.
///
/// The sprite files are produced from the source atlases by
/// `tools/slice_sprites.py`; the names here mirror that script exactly.
class Art {
  const Art._();

  static const String _sprites = 'assets/sprites';
  static const String _extra = 'assets/Lavawake_Rush_additional_assets';
  static const String _gameplay = 'assets/Lavawake_Rush_gameplay_assets';

  static const String wordmark = '$_extra/Game_Name.webp';
  static const String loadingLandscape = '$_extra/Horizontal_Loading_Screen.webp';
  static const String loadingPortrait = '$_extra/Vertical_Loading_Screen.webp';
  static const String appIcon = 'assets/icon/icon.png';

  static String sprite(String name) => '$_sprites/$name.png';

  static const List<String> locations = [
    '$_gameplay/bg_location_1_asset.webp',
    '$_gameplay/bg_location_2_asset.webp',
    '$_gameplay/bg_location_3_asset.webp',
    '$_gameplay/bg_location_4_asset.webp',
    '$_gameplay/bg_location_5_asset.webp',
    '$_gameplay/bg_location_6_asset.webp',
  ];

  /// The eight player evolution stages, in ascending order.
  static const List<String> playerStages = [
    'player_stage_1_droplet',
    'player_stage_2_splash',
    'player_stage_3_crust',
    'player_stage_4_basalt',
    'player_stage_5_forged',
    'player_stage_6_inferno',
    'player_stage_7_crystalline',
    'player_stage_8_prime',
  ];

  static const List<String> effects = [
    'fx_lava_vortex',
    'fx_crystal_burst',
    'fx_ash_eruption',
    'fx_ember_spray',
    'fx_magma_droplets',
    'fx_metal_splash',
    'fx_ice_burst',
    'fx_obsidian_burst',
    'fx_smoke_puff',
    'fx_heat_ripple',
    'fx_fire_swirl',
    'fx_shock_ring',
    'fx_shard_scatter',
    'fx_ground_crack',
    'fx_ash_plume',
  ];

  static const List<String> obstacles = [
    'obj_rock_cluster',
    'obj_cracked_boulder',
    'obj_ruby_spikes',
    'obj_basalt_platform',
    'obj_lava_pillar',
    'obj_obsidian_spikes',
    'obj_ember_nodes',
    'obj_magma_tiles',
    'obj_glow_boulder',
    'obj_amethyst_mound',
    'obj_bubbling_mound',
    'obj_stone_column',
    'obj_core_geyser',
    'obj_stepping_stones',
    'obj_magma_shards',
    'obj_ruby_deposit',
    'obj_basalt_tower',
    'obj_vent_mound',
  ];
}

class Sfx {
  const Sfx._();

  static const String _root = 'Lavawake_Rush_sounds_assets';

  static const String tap = '$_root/button_click_asset.mp3';
  static const String hover = '$_root/button_hover_asset.mp3';
  static const String back = '$_root/back_button_asset.mp3';
  static const String confirm = '$_root/confirm_asset.mp3';
  static const String cancel = '$_root/cancel_asset.mp3';
  static const String error = '$_root/error_asset.mp3';
  static const String menuOpen = '$_root/menu_open_asset.mp3';
  static const String menuClose = '$_root/menu_close_asset.mp3';
  static const String popup = '$_root/popup_appear_asset.mp3';
  static const String toggle = '$_root/toggle_switch_asset.mp3';
  static const String unlock = '$_root/unlock_asset.mp3';
  static const String reward = '$_root/reward_received_asset.mp3';
  static const String notification = '$_root/notification_asset.mp3';
  static const String progress = '$_root/progress_fill_asset.mp3';
  static const String transition = '$_root/scene_transition_asset.mp3';
  static const String levelStart = '$_root/level_start_asset.mp3';
  static const String levelComplete = '$_root/level_complete_asset.mp3';
  static const String levelFailed = '$_root/level_failed_asset.mp3';
  static const String menuAmbient = '$_root/menu_ambient_loop_asset.mp3';
  static const String loadingLoop = '$_root/loading_loop_asset.mp3';
}
