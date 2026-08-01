module main

import gui
import time
import guard_ui
import config
import vpn

fn main() {
	// Load persisted tunnels and settings from disk
	saved_tunnels := config.load_tunnels()
	app_settings := config.load_settings()

	// Read initial live stats (best-effort; wg may not be running yet)
	initial_stats := vpn.read_stats()

	mut connected_map := map[string]bool{}

	// Handle auto-connect on startup if configured
	if app_settings.auto_connect && app_settings.auto_connect_tunnel != '' {
		for conf in saved_tunnels {
			if conf.name == app_settings.auto_connect_tunnel {
				vpn.activate_tunnel(conf) or {}
				connected_map[conf.name] = true
				break
			}
		}
	}

	refresh_delay := if app_settings.refresh_interval_sec > 0 {
		app_settings.refresh_interval_sec
	} else {
		15
	}

	mut window := gui.window(
		title:        'V-Guard — WireGuard Client'
		width:        450
		height:       700
		cursor_blink: true // required for input fields and UI responsiveness
		state:        &guard_ui.AppState{
			tunnels:   saved_tunnels
			connected: connected_map
			stats:     initial_stats
			settings:  app_settings
		}
		on_init:      fn [refresh_delay] (mut w gui.Window) {
			w.set_theme(gui.theme_dark)
			w.update_view(guard_ui.main_view)
			// Refresh stats periodically based on settings
			mut anim := gui.Animate{
				id:       'stats_refresh'
				delay:    refresh_delay * time.second
				repeat:   true
				callback: fn (mut _ gui.Animate, mut w gui.Window) {
					guard_ui.refresh_stats_anim(mut w)
				}
			}
			w.animation_add(mut anim)
		}
	)

	window.run()
}
