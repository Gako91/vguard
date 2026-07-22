module guard_ui

import gui
import config

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
// Form input component
// -----------------------------------------------------------------------

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
				text:            value
				placeholder:     placeholder
				on_text_changed: on_change
			),
		]
	)
}

// -----------------------------------------------------------------------
// Form overlay panel
// -----------------------------------------------------------------------

fn form_overlay_view(w_px int, h_px int, app &AppState, is_edit bool) gui.View {
	title := if is_edit { 'Éditer le tunnel' } else { 'Nouveau tunnel WireGuard' }
	ok_text := if is_edit { 'Enregistrer' } else { 'Créer' }

	max_h := if h_px - 40 > 100 { f32(h_px - 40) } else { f32(100) }

	form_panel := gui.column(
		width:        400
		max_height:   max_h
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
			gui.text(
				text:       app.error_msg
				text_style: text_style_red()
			),
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
// Stat card component
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
			gui.text(text: label, text_style: text_style_muted(), mode: .wrap),
		]
	)
}

// -----------------------------------------------------------------------
// Tunnel card component
// -----------------------------------------------------------------------

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
				spacing: 16
				content: [
					gui.row(
						sizing:  gui.fill_fit
						padding: gui.padding_none
						spacing: 8
						v_align: .middle
						content: [
							gui.text(text: 'Endpoint:', text_style: text_style_muted()),
							gui.text(
								text:       if conf.endpoint != '' { conf.endpoint } else { '—' }
								text_style: text_style_base()
								mode:       .wrap
							),
						]
					),
					gui.row(
						sizing:  gui.fill_fit
						padding: gui.padding_none
						spacing: 8
						v_align: .middle
						content: [
							gui.text(text: 'IP:', text_style: text_style_muted()),
							gui.text(
								text:       if conf.address != '' { conf.address } else { '—' }
								text_style: text_style_base()
								mode:       .wrap
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
