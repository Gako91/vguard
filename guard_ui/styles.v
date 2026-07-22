module guard_ui

import gui

// -----------------------------------------------------------------------
// Color palette
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

// -----------------------------------------------------------------------
// Text styles
// -----------------------------------------------------------------------

fn text_style_base() gui.TextStyle {
	return gui.TextStyle{
		...gui.theme().n3
		color: color_text
	}
}

fn text_style_muted() gui.TextStyle {
	return gui.TextStyle{
		...gui.theme().n4
		color: color_white
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
