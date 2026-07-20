module main

import gui
import time
import guard_ui
import config
import vpn

fn main() {
	// Load persisted tunnels from disk
	saved_tunnels := config.load_tunnels()

	// Read initial live stats (best-effort; wg may not be running yet)
	initial_stats := vpn.read_stats()

	mut window := gui.window(
		title:        'V-Guard — WireGuard Client'
		width:        570
		height:       680
		cursor_blink: true // required for input fields and UI responsiveness
		state:        &guard_ui.AppState{
			tunnels:   saved_tunnels
			connected: map[string]bool{}
			stats:     initial_stats
		}
		on_init:      fn (mut w gui.Window) {
			w.set_theme(gui.theme_dark)
			w.update_view(guard_ui.main_view)
			// Refresh stats every 15 seconds
			mut anim := gui.Animate{
				id:       'stats_refresh'
				delay:    15 * time.second
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
