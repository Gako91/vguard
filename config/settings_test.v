module config

fn test_settings() {
	def := default_settings()
	assert def.refresh_interval_sec == 15
	assert def.auto_connect == false
	assert def.show_notifications == true
	assert def.theme == 'dark'

	custom := AppSettings{
		refresh_interval_sec: 30
		auto_connect:         true
		auto_connect_tunnel:  'HomeVPN'
		show_notifications:   false
		theme:                'light'
	}
	save_settings(custom)
	loaded := load_settings()
	assert loaded.refresh_interval_sec == 30
	assert loaded.auto_connect == true
	assert loaded.auto_connect_tunnel == 'HomeVPN'
	assert loaded.show_notifications == false
	assert loaded.theme == 'light'

	// Cleanup test settings and restore defaults
	save_settings(def)
}
