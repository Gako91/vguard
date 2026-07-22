module guard_ui

import gui
import time
import config
import vpn

// -----------------------------------------------------------------------
// State
// -----------------------------------------------------------------------

// DialogMode tracks which form overlay is currently visible
pub enum DialogMode {
	none
	new_tunnel
	edit_tunnel
}

// NewTunnelForm holds the draft fields for the Nouveau / Éditer overlay
pub struct NewTunnelForm {
pub mut:
	name        string
	address     string
	private_key string
	public_key  string
	endpoint    string
	allowed_ips string
	dns         string
}

// AppState holds the full runtime state of the application
@[heap]
pub struct AppState {
pub mut:
	tunnels      []config.WGConfig
	connected    map[string]bool
	stats        map[string]vpn.TunnelStats
	error_msg    string
	last_refresh time.Time
	form         NewTunnelForm
	dialog_mode  DialogMode
	edit_idx     int // index of the tunnel being edited (-1 = none)
}

// -----------------------------------------------------------------------
// Persistence / stats helpers
// -----------------------------------------------------------------------

fn save(state &AppState) {
	config.save_tunnels(state.tunnels)
}

fn refresh_stats(mut w gui.Window) {
	mut state := w.state[AppState]()
	state.stats = vpn.read_stats()
	state.last_refresh = time.now()
	for name, _ in state.connected {
		if s := state.stats[name] {
			if !s.is_active {
				state.connected[name] = false
			}
		}
	}
}

pub fn refresh_stats_anim(mut w gui.Window) {
	refresh_stats(mut w)
	w.toast(gui.ToastCfg{
		body:     'Statistiques mises à jour'
		severity: .info
		duration: 2 * time.second
	})
}

// -----------------------------------------------------------------------
// VPN actions
// -----------------------------------------------------------------------

fn toggle_tunnel(idx int, mut w gui.Window) {
	mut state := w.state[AppState]()
	if idx < 0 || idx >= state.tunnels.len {
		return
	}
	conf := state.tunnels[idx]
	on := state.connected[conf.name] or { false }
	if on {
		vpn.cut_tunnel(conf) or {
			state.error_msg = 'Erreur déconnexion : ${err.msg()}'
			return
		}
		state.connected[conf.name] = false
		w.toast(gui.ToastCfg{
			body:     'Tunnel "${conf.name}" déconnecté'
			severity: .warning
			duration: 3 * time.second
		})
	} else {
		vpn.activate_tunnel(conf) or {
			state.error_msg = 'Erreur connexion : ${err.msg()}'
			return
		}
		state.connected[conf.name] = true
		w.toast(gui.ToastCfg{
			body:     'Tunnel "${conf.name}" connecté'
			severity: .success
			duration: 3 * time.second
		})
	}
	state.error_msg = ''
	refresh_stats(mut w)
}

fn delete_tunnel(idx int, mut w gui.Window) {
	mut state := w.state[AppState]()
	if idx < 0 || idx >= state.tunnels.len {
		return
	}
	name := state.tunnels[idx].name
	if state.connected[name] or { false } {
		vpn.cut_tunnel(state.tunnels[idx]) or {}
		state.connected.delete(name)
	}
	state.tunnels.delete(idx)
	save(state)
	w.toast(gui.ToastCfg{
		body:     'Tunnel "${name}" supprimé'
		severity: .warning
		duration: 3 * time.second
	})
}
