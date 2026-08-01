module vpn

import os

// TunnelStats holds live transfer statistics for one WireGuard interface
pub struct TunnelStats {
pub mut:
	bytes_received u64
	bytes_sent     u64
	is_active      bool
}

// format_bytes returns a human-readable string for a byte count (B / KiB / MiB / GiB)
pub fn format_bytes(n u64) string {
	if n < 1024 {
		return '${n} B'
	} else if n < 1024 * 1024 {
		kb := f64(n) / 1024.0
		return '${kb:.1f} KiB'
	} else if n < 1024 * 1024 * 1024 {
		mb := f64(n) / (1024.0 * 1024.0)
		return '${mb:.1f} MiB'
	} else {
		gb := f64(n) / (1024.0 * 1024.0 * 1024.0)
		return '${gb:.2f} GiB'
	}
}

// StatsResult encapsulates statistics along with potential system diagnostic messages
pub struct StatsResult {
pub mut:
	stats     map[string]TunnelStats
	error_msg string
}

// read_stats runs `wg show all dump` and parses per-interface byte counters.
// Returns a map keyed by interface name.
// `wg show all dump` format (tab-separated):
//   interface line : <iface> <private_key> <public_key> <listen_port> <fwmark>
//   peer line      : <iface> <public_key> <preshared_key> <endpoint> <allowed_ips>
//                    <latest_handshake> <transfer_rx> <transfer_tx> <persistent_keepalive>
pub fn read_stats() map[string]TunnelStats {
	res := read_stats_detailed()
	return res.stats
}

// read_stats_detailed runs `wg show all dump` and captures errors if sudo or wg fail.
pub fn read_stats_detailed() StatsResult {
	mut result := map[string]TunnelStats{}

	$if linux {
		res := os.execute('sudo -n wg show all dump')
		if res.exit_code != 0 {
			out := res.output.trim_space()
			mut msg := ''
			if out.contains('a terminal is required') || out.contains('password')
				|| out.contains('not permitted') {
				msg = 'Statistiques indisponibles : sudo nécessite la configuration NOPASSWD pour "wg" dans /etc/sudoers.d/vguard.'
			} else if out.contains('command not found') {
				msg = 'Statistiques indisponibles : l\'outil "wg" est introuvable sur le système.'
			}
			return StatsResult{
				stats:     result
				error_msg: msg
			}
		}

		for line in res.output.split_into_lines() {
			parts := line.split('\t')
			if parts.len < 9 {
				continue
			}
			iface := parts[0]
			rx := parts[6].u64()
			tx := parts[7].u64()
			handshake := parts[5].u64()

			mut stats := result[iface] or { TunnelStats{} }
			stats.bytes_received += rx
			stats.bytes_sent += tx
			if handshake > 0 {
				stats.is_active = true
			}
			result[iface] = stats
		}
		return StatsResult{
			stats:     result
			error_msg: ''
		}
	} $else {
		res := os.execute('wg show all dump')
		if res.exit_code != 0 {
			return StatsResult{
				stats:     result
				error_msg: ''
			}
		}

		for line in res.output.split_into_lines() {
			parts := line.split('\t')
			if parts.len < 9 {
				continue
			}
			iface := parts[0]
			rx := parts[6].u64()
			tx := parts[7].u64()
			handshake := parts[5].u64()

			mut stats := result[iface] or { TunnelStats{} }
			stats.bytes_received += rx
			stats.bytes_sent += tx
			if handshake > 0 {
				stats.is_active = true
			}
			result[iface] = stats
		}
		return StatsResult{
			stats:     result
			error_msg: ''
		}
	}
}

// total_transferred sums rx + tx across all interfaces
pub fn total_transferred(stats map[string]TunnelStats) u64 {
	mut total := u64(0)
	for _, s in stats {
		total += s.bytes_received + s.bytes_sent
	}
	return total
}

// active_count returns the number of active interfaces
pub fn active_count(stats map[string]TunnelStats) int {
	mut count := 0
	for _, s in stats {
		if s.is_active {
			count++
		}
	}
	return count
}
