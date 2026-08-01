module config

import json2
import os

// AppSettings holds application-wide preferences
pub struct AppSettings {
pub mut:
	refresh_interval_sec int
	auto_connect         bool
	auto_connect_tunnel  string
	show_notifications   bool
	theme                string
}

// default_settings returns default preferences
pub fn default_settings() AppSettings {
	return AppSettings{
		refresh_interval_sec: 15
		auto_connect:         false
		auto_connect_tunnel:  ''
		show_notifications:   true
		theme:                'dark'
	}
}

// settings_path returns the path to settings.json
fn settings_path() string {
	home := os.home_dir()
	dir := os.join_path(home, '.config', 'vguard')
	os.mkdir_all(dir) or {}
	return os.join_path(dir, 'settings.json')
}

// load_settings reads settings from disk or returns defaults if missing
pub fn load_settings() AppSettings {
	data := os.read_file(settings_path()) or { return default_settings() }
	s := json2.decode[AppSettings](data) or { return default_settings() }
	// Sanity checks
	mut res := s
	if res.refresh_interval_sec <= 0 {
		res.refresh_interval_sec = 15
	}
	if res.theme == '' {
		res.theme = 'dark'
	}
	return res
}

// save_settings persists settings to disk
pub fn save_settings(s AppSettings) {
	data := json2.encode(s)
	os.write_file(settings_path(), data) or {}
}
