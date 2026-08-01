module guard_ui

import gui
import vpn

// -----------------------------------------------------------------------
// Header view
// -----------------------------------------------------------------------

fn header_view(app &AppState) gui.View {
	mut refresh_label := '—'
	if app.last_refresh.unix() != 0 {
		h := app.last_refresh.hour
		m := app.last_refresh.minute
		s := app.last_refresh.second
		refresh_label = '${h:02d}:${m:02d}:${s:02d}'
	}
	return gui.wrap(
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
					gui.text(text: 'WireGuard VPN', text_style: text_style_title(), mode: .wrap),
					gui.wrap(
						padding: gui.padding_none
						spacing: 6
						v_align: .middle
						content: [
							gui.text(
								text:       'Gestionnaire de connexions'
								text_style: text_style_muted()
								mode:       .wrap
							),
							gui.text(text: '·', text_style: text_style_muted()),
							gui.text(
								text:       'Màj ${refresh_label}'
								text_style: text_style_muted()
								mode:       .wrap
							),
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
			gui.button(
				content:  [
					gui.row(
						padding: gui.padding_none
						spacing: 4
						v_align: .middle
						content: [
							gui.text(
								text:       '⚙'
								text_style: gui.TextStyle{
									...gui.theme().b3
									color: color_white
								}
							),
						]
					),
				]
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					open_settings_dialog(mut w)
				}
			),
			gui.button(
				content:  [
					gui.row(
						padding: gui.padding_none
						spacing: 4
						v_align: .middle
						content: [
							gui.text(
								text:       '?'
								text_style: gui.TextStyle{
									...gui.theme().b3
									color: color_white
								}
							),
						]
					),
				]
				on_click: fn (_ &gui.Layout, mut _ gui.Event, mut w gui.Window) {
					open_help_dialog(mut w)
				}
			),
		]
	)
}

// -----------------------------------------------------------------------
// Stats row with stat cards
// -----------------------------------------------------------------------

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

// -----------------------------------------------------------------------
// Tunnel list view
// -----------------------------------------------------------------------

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
		sizing:    gui.fill_fill
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
			content: [
				gui.text(
					text:       app.error_msg
					text_style: text_style_red()
					mode:       .wrap
				),
			]
		)
	}
	content << tunnel_list_view(app)

	if app.dialog_mode != .none {
		if app.dialog_mode == .settings {
			content << settings_overlay_view(w, h, app)
		} else if app.dialog_mode == .help {
			content << help_overlay_view(w, h, app)
		} else {
			is_edit := app.dialog_mode == .edit_tunnel
			content << form_overlay_view(w, h, app, is_edit)
		}
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
