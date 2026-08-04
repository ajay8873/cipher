class AppConfig {
  /// Current App Version (Matches pubspec.yaml version)
  static const String currentVersion = "1.1.0";

  /// GitHub Repository details for auto-update checks
  static const String githubRepoOwner = "ajay8873";
  static const String githubRepoName = "cipher";

  /// Official Cloudflare Pages Download Website URL
  static const String downloadWebsiteUrl = "https://cipher-khata.pages.dev";

  /// DeepSeek API Key (Get your key from https://platform.deepseek.com)
  static const String deepSeekApiKey = "YOUR_DEEPSEEK_API_KEY_HERE";

  /// Supabase Configuration (Optional for cloud sync)
  static const String supabaseUrl = "YOUR_SUPABASE_URL_HERE";
  static const String supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY_HERE";

  /// Returns true if DeepSeek API key is configured
  static bool get isDeepSeekConfigured =>
      deepSeekApiKey.isNotEmpty && deepSeekApiKey != "YOUR_DEEPSEEK_API_KEY_HERE";
}
