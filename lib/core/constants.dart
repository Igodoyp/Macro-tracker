class AppConfig {
	static const String supabaseUrl = String.fromEnvironment(
		'SUPABASE_URL',
		defaultValue: '',
	);

	static const String supabaseAnonKey = String.fromEnvironment(
		'SUPABASE_ANON_KEY',
		defaultValue: '',
	);

	static const String geminiApiKey = String.fromEnvironment(
		'GEMINI_API_KEY',
		defaultValue: '',
	);

	static const String fallbackUserId = String.fromEnvironment(
		'SUPABASE_DEMO_USER_ID',
		defaultValue: '',
	);

	static bool get hasSupabaseCredentials =>
			supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

	static bool get hasGeminiCredentials => geminiApiKey.isNotEmpty;
}
