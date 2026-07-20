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
	if idx < 0 || idx >= state.tunnels.len { return }
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
	if idx < 0 || idx >= state.tunnels.len { return }
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

// id_focus constants for form fields
const form_id_name = u32(7568980)
const form_id_address = u32(7568981)
const form_id_private_key = u32(7568982)
const form_id_public_key = u32(7568983)
const form_id_endpoint = u32(7568984)
const form_id_allowed_ips = u32(7568985)
const form_id_dns = u32(7568986)
const form_id_cancel = u32(7568987)
const form_id_ok = u32(7568988)

// -----------------------------------------------------------------------
// Color helpers
// -----------------------------------------------------------------------

const color_bg = gui.Color{
	r: 13
	g: 17
	b: 30
	a: 255
}
const color_panel = gui.Color{
	r: 22
	g: 28
	b: 45
	a: 255
}
const color_card = gui.Color{
	r: 30
	g: 37
	b: 58
	a: 255
}
const color_border = gui.Color{
	r: 50
	g: 60
	b: 90
	a: 255
}
const color_blue = gui.Color{
	r: 30
	g: 100
	b: 200
	a: 255
}
const color_green = gui.Color{
	r: 34
	g: 197
	b: 94
	a: 255
}
const color_red = gui.Color{
	r: 220
	g: 60
	b: 60
	a: 255
}
const color_text = gui.Color{
	r: 220
	g: 225
	b: 240
	a: 255
}
const color_muted = gui.Color{
	r: 130
	g: 140
	b: 170
	a: 255
}
const color_white = gui.Color{
	r: 255
	g: 255
	b: 255
	a: 255
}
const color_overlay = gui.Color{
	r: 0
	g: 0
	b: 0
	a: 180
}

fn text_style_base() gui.TextStyle {
	return gui.TextStyle{
		...gui.theme().n3
		color: color_text
	}
}

fn text_style_muted() gui.TextStyle {
	return gui.TextStyle{
		...gui.theme().n4
		color: color_muted
	}
}

fn text_style_bold() gui.TextStyle {
	return gui.TextStyle{
		...gui.theme().b3
		color: color_text
	}
}

fn text_style_title() gui.TextStyle {
	return gui.TextStyle{
		...gui.theme().b1
		color: color_white
	}
}

fn text_style_stat() gui.TextStyle {
	return gui.TextStyle{
		...gui.theme().b1
		color: color_white
	}
}

fn text_style_blue() gui.TextStyle {
	return gui.TextStyle{
		...gui.theme().n4
		color: color_blue
	}
}

fn text_style_red() gui.TextStyle {
	return gui.TextStyle{
		...gui.theme().n4
		color: color_red
	}
}

// -----------------------------------------------------------------------
// Form overlay — rendered every frame from main_view so inputs are live
// -----------------------------------------------------------------------

// form_input renders one labeled input row, binding text to the live value
fn form_input(label string, value string, placeholder string, id_focus u32,
	on_change fn (&gui.Layout, string, mut gui.Window)) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		padding: gui.padding_none
		spacing: 4
		content: [
			gui.text(text: label, text_style: text_style_muted()),
			gui.input(
				id_focus:        id_focus
				sizing:          gui.fill_fit
				text:            value // bound to live state every frame
				placeholder:     placeholder
				on_text_changed: on_change
			),
		]
	)
}

// form_overlay_view builds the form panel, re-evaluated every frame
fn form_overlay_view(w_px int, h_px int, app &AppState, is_edit bool) gui.View {
	title := if is_edit { 'Éditer le tunnel' } else { 'Nouveau tunnel WireGuard' }
	ok_text := if is_edit { 'Enregistrer' } else { 'Créer' }

	form_panel := gui.column(
		width:        460
		sizing:       gui.fixed_fit
		color:        color_panel
		radius:       10
		size_border:  1
		color_border: color_border
		padding:      gui.Padding{
			top:    24
			bottom: 24
			left:   28
			right:  28
		}
		spacing:      14
		id_scroll:    9
		content:      [
			gui.text(text: title, text_style: text_style_bold()),
			form_input('Nom *', app.form.name, 'ex: home-vpn', form_id_name, fn (_ &gui.Layout, s string, mut w gui.Window) {
				mut st := w.state[AppState]()
				st.form.name = s
			}),
			form_input('Adresse IP (CIDR) *', app.form.address, 'ex: 10.0.0.2/24', form_id_address, fn (_ &gui.Layout, s string, mut w gui.Window) {
				mut st := w.state[AppState]()
				st.form.address = s
			}),
			form_input('Clé privée *', app.form.private_key, 'Private key base64',
				form_id_private_key, fn (_ &gui.Layout, s string, mut w gui.Window) {
				mut st := w.state[AppState]()
				st.form.private_key = s
			}),
			form_input('Clé publique du pair *', app.form.public_key, 'Public key base64',
				form_id_public_key, fn (_ &gui.Layout, s string, mut w gui.Window) {
				mut st := w.state[AppState]()
				st.form.public_key = s
			}),
			form_input('Endpoint', app.form.endpoint, 'ex: vpn.exemple.com:51820',
				form_id_endpoint, fn (_ &gui.Layout, s string, mut w gui.Window) {
				mut st := w.state[AppState]()
				st.form.endpoint = s
			}),
			form_input('Allowed IPs', app.form.allowed_ips, 'ex: 0.0.0.0/0', form_id_allowed_ips, fn (_ &gui.Layout, s string, mut w gui.Window) {
				mut st := w.state[AppState]()
				st.form.allowed_ips = s
			}),
			form_input('DNS', app.form.dns, 'ex: 1.1.1.1', form_id_dns, fn (_ &gui.Layout, s string, mut w gui.Window) {
				mut st := w.state[AppState]()
				st.form.dns = s
			}),
			// Error message (always present; empty when no error)
			gui.text(
				text:       app.error_msg
				text_style: text_style_red()
			),
			// Buttons
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				h_align: .end
				spacing: 10
				content: [
					gui.button(
						id_focus: form_id_cancel
						content:  [gui.text(text: 'Annuler')]
						on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							close_dialog(mut w)
						}
					),
					gui.button(
						id_focus: form_id_ok
						content:  [gui.text(text: ok_text)]
						on_click: fn [is_edit] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							if is_edit {
								submit_edit_tunnel(mut w)
							} else {
								submit_new_tunnel(mut w)
							}
						}
					),
				]
			),
		]
	)

	// Full-screen semi-transparent overlay + centered panel
	return gui.column(
		width:         w_px
		height:        h_px
		sizing:        gui.fixed_fixed
		color:         color_overlay
		float:         true
		float_anchor:  .middle_center
		float_tie_off: .middle_center
		h_align:       .center
		v_align:       .middle
		padding:       gui.padding_none
		on_click:      fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
			close_dialog(mut w)
		}
		content:       [form_panel]
	)
}

// -----------------------------------------------------------------------
// Delete confirm dialog (uses built-in dialog — no input needed → OK)
// -----------------------------------------------------------------------

fn open_delete_confirm(idx int, tunnel_name string, mut w gui.Window) {
	w.dialog(
		dialog_type:  .confirm
		title:        'Supprimer le tunnel'
		body:         'Supprimer "${tunnel_name}" ? Cette action est irréversible.'
		on_ok_yes:    fn [idx] (mut w gui.Window) {
			delete_tunnel(idx, mut w)
		}
		on_cancel_no: fn (mut _ gui.Window) {}
	)
}

// -----------------------------------------------------------------------
// Header
// -----------------------------------------------------------------------

fn header_view(app &AppState) gui.View {
	mut refresh_label := '—'
	if app.last_refresh.unix() != 0 {
		h := app.last_refresh.hour
		m := app.last_refresh.minute
		s := app.last_refresh.second
		refresh_label = '${h:02d}:${m:02d}:${s:02d}'
	}
	return gui.row(
		sizing:  gui.fill_fit
		padding: gui.Padding{
			top:    16
			bottom: 16
			left:   20
			right:  20
		}
		color:   color_panel
		v_align: .middle
		spacing: 12
		content: [
			gui.column(
				width:   36
				height:  36
				sizing:  gui.fixed_fixed
				color:   color_blue
				radius:  6
				h_align: .center
				v_align: .middle
				padding: gui.padding_none
				content: [
					gui.text(
						text:       'VG'
						text_style: gui.TextStyle{
							...gui.theme().b3
							color: color_white
						}
					),
				]
			),
			gui.column(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				spacing: 2
				content: [
					gui.text(text: 'WireGuard VPN', text_style: text_style_title()),
					gui.row(
						padding: gui.padding_none
						spacing: 6
						v_align: .middle
						content: [
							gui.text(
								text:       'Gestionnaire de connexions'
								text_style: text_style_muted()
							),
							gui.text(text: '·', text_style: text_style_muted()),
							gui.text(text: 'Màj ${refresh_label}', text_style: text_style_muted()),
						]
					),
				]
			),
			gui.button(
				content:  [
					gui.row(
						padding: gui.padding_none
						spacing: 6
						v_align: .middle
						content: [
							gui.text(
								text:       '↑'
								text_style: gui.TextStyle{
									...gui.theme().b3
									color: color_white
								}
							),
							gui.text(
								text:       'Importer'
								text_style: gui.TextStyle{
									...gui.theme().n3
									color: color_white
								}
							),
						]
					),
				]
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					import_conf(mut w)
				}
			),
			gui.button(
				content:  [
					gui.row(
						padding: gui.padding_none
						spacing: 6
						v_align: .middle
						content: [
							gui.text(
								text:       '+'
								text_style: gui.TextStyle{
									...gui.theme().b3
									color: color_white
								}
							),
							gui.text(
								text:       'Nouveau'
								text_style: gui.TextStyle{
									...gui.theme().n3
									color: color_white
								}
							),
						]
					),
				]
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					open_new_dialog(mut w)
				}
			),
		]
	)
}

// -----------------------------------------------------------------------
// Stats row + tunnel cards
// -----------------------------------------------------------------------

fn stat_card(value string, label string, card_color gui.Color) gui.View {
	return gui.column(
		sizing:  gui.fill_fit
		color:   card_color
		radius:  8
		padding: gui.Padding{
			top:    16
			bottom: 16
			left:   20
			right:  20
		}
		spacing: 6
		content: [
			gui.text(text: value, text_style: text_style_stat()),
			gui.text(text: label, text_style: text_style_muted()),
		]
	)
}

fn stats_row(app &AppState) gui.View {
	return gui.row(
		sizing:  gui.fill_fit
		padding: gui.Padding{
			top:    0
			bottom: 0
			left:   20
			right:  20
		}
		spacing: 16
		content: [
			stat_card('${vpn.active_count(app.stats)}', 'Connexions actives', color_blue),
			stat_card('${app.tunnels.len}', 'Tunnels configurés', color_card),
			stat_card(vpn.format_bytes(vpn.total_transferred(app.stats)), 'Données transférées',
				color_green),
		]
	)
}

fn tunnel_card(idx int, conf config.WGConfig, is_on bool) gui.View {
	status_label := if is_on { 'Actif' } else { 'Inactif' }
	status_ts := if is_on { text_style_blue() } else { text_style_muted() }
	captured_idx := idx
	captured_conf := conf
	return gui.column(
		sizing:       gui.fill_fit
		color:        color_card
		radius:       8
		size_border:  1
		color_border: color_border
		padding:      gui.Padding{
			top:    16
			bottom: 16
			left:   20
			right:  20
		}
		spacing:      10
		content:      [
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				v_align: .middle
				content: [
					gui.row(
						sizing:  gui.fill_fit
						padding: gui.padding_none
						spacing: 10
						v_align: .middle
						content: [
							gui.text(text: '⬡', text_style: text_style_muted()),
							gui.text(text: conf.name, text_style: text_style_bold()),
						]
					),
					gui.row(
						padding: gui.padding_none
						spacing: 8
						v_align: .middle
						content: [
							gui.text(text: status_label, text_style: status_ts),
							gui.switch(
								select:   is_on
								on_click: fn [captured_idx] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
									toggle_tunnel(captured_idx, mut w)
								}
							),
						]
					),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				spacing: 30
				content: [
					gui.row(
						padding: gui.padding_none
						spacing: 8
						v_align: .middle
						content: [
							gui.text(text: 'Endpoint:', text_style: text_style_muted()),
							gui.text(
								text:       if conf.endpoint != '' { conf.endpoint } else { '—' }
								text_style: text_style_base()
							),
						]
					),
					gui.row(
						padding: gui.padding_none
						spacing: 8
						v_align: .middle
						content: [
							gui.text(text: 'IP:', text_style: text_style_muted()),
							gui.text(
								text:       if conf.address != '' { conf.address } else { '—' }
								text_style: text_style_base()
							),
						]
					),
				]
			),
			gui.row(
				sizing:  gui.fill_fit
				padding: gui.padding_none
				h_align: .end
				spacing: 16
				content: [
					gui.button(
						content:  [
							gui.row(
								padding: gui.padding_none
								spacing: 4
								v_align: .middle
								content: [
									gui.text(text: '✏', text_style: text_style_blue()),
									gui.text(text: 'Éditer', text_style: text_style_blue()),
								]
							),
						]
						on_click: fn [captured_idx, captured_conf] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							open_edit_dialog(captured_idx, captured_conf, mut w)
						}
					),
					gui.button(
						content:  [
							gui.row(
								padding: gui.padding_none
								spacing: 4
								v_align: .middle
								content: [
									gui.text(text: '🗑', text_style: text_style_red()),
									gui.text(text: 'Supprimer', text_style: text_style_red()),
								]
							),
						]
						on_click: fn [captured_idx, captured_conf] (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
							open_delete_confirm(captured_idx, captured_conf.name, mut w)
						}
					),
				]
			),
		]
	)
}

fn tunnel_list_view(app &AppState) gui.View {
	mut cards := []gui.View{}
	for i, t in app.tunnels {
		cards << tunnel_card(i, t, app.connected[t.name] or { false })
	}
	if cards.len == 0 {
		cards << gui.column(
			sizing:  gui.fill_fit
			h_align: .center
			padding: gui.Padding{
				top:    40
				bottom: 40
				left:   0
				right:  0
			}
			content: [
				gui.text(
					text:       'Aucun tunnel configuré.\nCliquez sur "Importer" ou "Nouveau" pour commencer.'
					text_style: text_style_muted()
					mode:       .wrap
				),
			]
		)
	}
	return gui.column(
		sizing:    gui.fill_fit
		spacing:   12
		id_scroll: 1
		padding:   gui.Padding{
			top:    0
			bottom: 20
			left:   20
			right:  20
		}
		content:   cards
	)
}

// -----------------------------------------------------------------------
// Main view — re-evaluated every frame
// -----------------------------------------------------------------------

pub fn main_view(window &gui.Window) gui.View {
	w, h := window.window_size()
	app := window.state[AppState]()

	mut content := []gui.View{}
	content << header_view(app)
	content << gui.column(
		sizing:  gui.fill_fit
		padding: gui.Padding{
			top:    8
			bottom: 8
			left:   0
			right:  0
		}
		content: []
	)
	content << stats_row(app)
	content << gui.column(
		sizing:  gui.fill_fit
		padding: gui.Padding{
			top:    16
			bottom: 8
			left:   20
			right:  20
		}
		content: [gui.text(text: 'Mes tunnels VPN', text_style: text_style_bold())]
	)
	if app.error_msg != '' && app.dialog_mode == .none {
		content << gui.column(
			sizing:  gui.fill_fit
			padding: gui.Padding{
				top:    0
				bottom: 4
				left:   20
				right:  20
			}
			content: [gui.text(text: app.error_msg, text_style: text_style_red())]
		)
	}
	content << tunnel_list_view(app)

	// Form overlay — injected into content when a dialog is active.
	// Because main_view runs every frame, form_input fields get the
	// current AppState.form values, making typing work correctly.
	if app.dialog_mode != .none {
		is_edit := app.dialog_mode == .edit_tunnel
		content << form_overlay_view(w, h, app, is_edit)
	}

	return gui.column(
		width:   w
		height:  h
		sizing:  gui.fixed_fixed
		color:   color_bg
		padding: gui.padding_none
		spacing: 0
		content: content
	)
}
