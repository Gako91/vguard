module guard_ui

import gui
import time
import config

// -----------------------------------------------------------------------
// Dialog actions
// -----------------------------------------------------------------------

fn import_conf(mut w gui.Window) {
	w.native_open_dialog(
		title:   'Choisir une configuration WireGuard'
		filters: [gui.NativeFileFilter{ name: 'WireGuard Config', extensions: ['conf'] }]
		on_done: fn (result gui.NativeDialogResult, mut w gui.Window) {
			if result.status != .ok || result.paths.len == 0 { return }
			mut state := w.state[AppState]()
			new_conf := config.parse_wg_config(result.path_strings()[0]) or {
				state.error_msg = 'Erreur lecture .conf : ${err.msg()}'
				return
			}
			for t in state.tunnels {
				if t.name == new_conf.name {
					state.error_msg = 'Un tunnel "${new_conf.name}" existe déjà.'
					return
				}
			}
			state.tunnels << new_conf
			state.error_msg = ''
			save(state)
			w.toast(gui.ToastCfg{
				body:     'Tunnel "${new_conf.name}" importé'
				severity: .success
				duration: 3 * time.second
			})
		}
	)
}

fn open_new_dialog(mut w gui.Window) {
	mut state := w.state[AppState]()
	state.form = NewTunnelForm{}
	state.dialog_mode = .new_tunnel
	state.error_msg = ''
	w.set_id_focus(form_id_name)
}

fn open_edit_dialog(idx int, conf config.WGConfig, mut w gui.Window) {
	mut state := w.state[AppState]()
	state.form = NewTunnelForm{
		name:        conf.name
		address:     conf.address
		private_key: conf.private_key
		public_key:  conf.public_key
		endpoint:    conf.endpoint
		allowed_ips: conf.allowed_ips
		dns:         conf.dns
	}
	state.edit_idx = idx
	state.dialog_mode = .edit_tunnel
	state.error_msg = ''
	w.set_id_focus(form_id_name)
}

fn close_dialog(mut w gui.Window) {
	mut state := w.state[AppState]()
	state.dialog_mode = .none
	state.edit_idx = -1
	state.form = NewTunnelForm{}
}

fn submit_new_tunnel(mut w gui.Window) {
	mut st := w.state[AppState]()
	f := st.form
	if f.name.trim_space() == '' {
		st.error_msg = 'Le nom est obligatoire.'
		return
	}
	if f.address.trim_space() == '' || f.private_key.trim_space() == ''
		|| f.public_key.trim_space() == '' {
		st.error_msg = 'Adresse, clé privée et clé publique sont obligatoires.'
		return
	}
	for t in st.tunnels {
		if t.name == f.name.trim_space() {
			st.error_msg = 'Un tunnel "${f.name}" existe déjà.'
			return
		}
	}
	new_conf := config.WGConfig{
		name:        f.name.trim_space()
		address:     f.address.trim_space()
		private_key: f.private_key.trim_space()
		public_key:  f.public_key.trim_space()
		endpoint:    f.endpoint.trim_space()
		allowed_ips: f.allowed_ips.trim_space()
		dns:         f.dns.trim_space()
	}
	st.tunnels << new_conf
	save(st)
	close_dialog(mut w)
	w.toast(gui.ToastCfg{
		body:     'Tunnel "${new_conf.name}" créé'
		severity: .success
		duration: 3 * time.second
	})
}

fn submit_edit_tunnel(mut w gui.Window) {
	mut st := w.state[AppState]()
	idx := st.edit_idx
	if idx < 0 || idx >= st.tunnels.len {
		close_dialog(mut w)
		return
	}
	f := st.form
	if f.name.trim_space() == '' {
		st.error_msg = 'Le nom est obligatoire.'
		return
	}
	if f.address.trim_space() == '' || f.private_key.trim_space() == ''
		|| f.public_key.trim_space() == '' {
		st.error_msg = 'Adresse, clé privée et clé publique sont obligatoires.'
		return
	}
	old_name := st.tunnels[idx].name
	new_name := f.name.trim_space()
	if new_name != old_name {
		for t in st.tunnels {
			if t.name == new_name {
				st.error_msg = 'Un tunnel "${new_name}" existe déjà.'
				return
			}
		}
		was_on := st.connected[old_name] or { false }
		st.connected.delete(old_name)
		if was_on { st.connected[new_name] = true }
	}
	st.tunnels[idx] = config.WGConfig{
		name:        new_name
		address:     f.address.trim_space()
		private_key: f.private_key.trim_space()
		public_key:  f.public_key.trim_space()
		endpoint:    f.endpoint.trim_space()
		allowed_ips: f.allowed_ips.trim_space()
		dns:         f.dns.trim_space()
	}
	save(st)
	close_dialog(mut w)
	w.toast(gui.ToastCfg{
		body:     'Tunnel "${new_name}" mis à jour'
		severity: .success
		duration: 3 * time.second
	})
}

fn open_settings_dialog(mut w gui.Window) {
	mut state := w.state[AppState]()
	state.settings_form = SettingsForm{
		refresh_interval_sec: state.settings.refresh_interval_sec.str()
		auto_connect:         state.settings.auto_connect
		auto_connect_tunnel:  state.settings.auto_connect_tunnel
		show_notifications:   state.settings.show_notifications
		theme:                state.settings.theme
	}
	state.dialog_mode = .settings
	state.error_msg = ''
}

fn open_help_dialog(mut w gui.Window) {
	mut state := w.state[AppState]()
	state.dialog_mode = .help
	state.error_msg = ''
}

fn submit_settings(mut w gui.Window) {
	mut st := w.state[AppState]()
	f := st.settings_form
	interval := f.refresh_interval_sec.int()
	if interval <= 0 {
		st.error_msg = "L'intervalle doit être un nombre positif (ex: 15)."
		return
	}
	st.settings = config.AppSettings{
		refresh_interval_sec: interval
		auto_connect:         f.auto_connect
		auto_connect_tunnel:  f.auto_connect_tunnel
		show_notifications:   f.show_notifications
		theme:                f.theme
	}
	config.save_settings(st.settings)
	close_dialog(mut w)
	if st.settings.show_notifications {
		w.toast(gui.ToastCfg{
			body:     'Paramètres enregistrés'
			severity: .success
			duration: 3 * time.second
		})
	}
}

fn open_delete_confirm(idx int, tunnel_name string, mut w gui.Window) {
	w.dialog(
		dialog_type:  .confirm
		title:        'Supprimer le tunnel'
		body:         'Supprimer "${tunnel_name}" ?\nCette action est irréversible.'
		width:        380
		max_width:    400
		on_ok_yes:    fn [idx] (mut w gui.Window) {
			delete_tunnel(idx, mut w)
		}
		on_cancel_no: fn (mut _ gui.Window) {}
	)
}
