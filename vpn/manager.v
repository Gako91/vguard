module vpn

import os
import config

// activate_tunnel calls the system command to bring the VPN tunnel up
pub fn activate_tunnel(conf config.WGConfig) ! {
	$if linux {
		res := os.execute('sudo -n wg-quick up ${conf.name}')
		if res.exit_code != 0 {
			out := res.output.trim_space()
			if out.contains('a terminal is required') || out.contains('password')
				|| out.contains('not permitted') {
				return error('Privilèges sudo requis : Veuillez autoriser wg-quick sans mot de passe dans /etc/sudoers.d/vguard ou lancer vguard avec sudo.')
			}
			return error('Échec wg-quick up : ${out}')
		}
	} $else $if macos {
		res := os.execute('wg-quick up ${conf.name}')
		if res.exit_code != 0 {
			return error('macOS wg-quick up failed: ${res.output}')
		}
	} $else $if windows {
		res := os.execute('wireguard.exe /installtunnelservice "${conf.name}.conf"')
		if res.exit_code != 0 {
			return error('Windows WireGuard failed: ${res.output}')
		}
	}
}

// cut_tunnel calls the system command to bring the VPN tunnel down
pub fn cut_tunnel(conf config.WGConfig) ! {
	$if linux {
		res := os.execute('sudo -n wg-quick down ${conf.name}')
		if res.exit_code != 0 {
			out := res.output.trim_space()
			if out.contains('a terminal is required') || out.contains('password')
				|| out.contains('not permitted') {
				return error('Privilèges sudo requis : Veuillez autoriser wg-quick sans mot de passe dans /etc/sudoers.d/vguard ou lancer vguard avec sudo.')
			}
			return error('Échec wg-quick down : ${out}')
		}
	} $else $if macos {
		res := os.execute('wg-quick down ${conf.name}')
		if res.exit_code != 0 {
			return error('macOS wg-quick down failed: ${res.output}')
		}
	} $else $if windows {
		res := os.execute('wireguard.exe /uninstalltunnelservice "${conf.name}"')
		if res.exit_code != 0 {
			return error('Windows WireGuard uninstall failed: ${res.output}')
		}
	}
}
