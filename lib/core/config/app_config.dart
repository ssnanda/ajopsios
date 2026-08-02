/// Single-tenant app config for the NC LLC Agents ops app.
/// Unlike ajcoreios (multi-brand customer portal), this app has one
/// audience — staff — so there's no BuildConfig/builds/ abstraction here.
class AppConfig {
  AppConfig._();

  static const String appName = 'AJ Ops';

  static const String apiBaseUrl = String.fromEnvironment(
    'AJ_API_BASE_URL',
    defaultValue: 'https://ncllcagents.com/wp-json/ajcore/v1',
  );
}
