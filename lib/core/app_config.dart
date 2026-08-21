/// Static, build-time facts about the application.
class AppConfig {
  const AppConfig._();

  static const String appName = 'Lavawake Rush';
  static const String tagline = 'Awaken the flow. Devour the mountain.';
  static const String version = '1.0.2';

  static const String bundleId = 'com.lavawake.rushgame';
  static const String appStoreId = '6792859673';

  static const String privacyPolicyUrl = 'https://lavawakerush.com/privacy-policy.html';
  static const String supportUrl = 'https://lavawakerush.com/support.html';
  static const String supportEmail = 'support@lavawakerush.com';

  /// Bundled copies shown whenever the online pages cannot be reached, so the
  /// legal and support content is always available offline.
  static const String privacyPolicyAsset = 'assets/legal/privacy_policy.html';
  static const String supportAsset = 'assets/legal/support.html';

  /// Hard ceiling for the boot sequence. The loading screen must always finish
  /// inside this budget, even if asset warm-up stalls.
  static const Duration maxBootDuration = Duration(milliseconds: 9200);
}
