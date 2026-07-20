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

// read_stats runs `wg show all dump` and parses per-interface byte counters.
// Returns a map keyed by interface name.
// `wg show all dump` format (tab-separated):
//   interface line : <iface> <private_key> <public_key> <listen_port> <fwmark>
//   peer line      : <iface> <public_key> <preshared_key> <endpoint> <allowed_ips>
//                    <latest_handshake> <transfer_rx> <transfer_tx> <persistent_keepalive>
pub fn read_stats() map[string]TunnelStats {
	mut result := map[string]TunnelStats{}

	res := os.execute('sudo wg show all dump')
	if res.exit_code != 0 {
		return result
	}

	for line in res.output.split_into_lines() {
		parts := line.split('\t')
		// Peer lines have 9 fields; interface lines have 5
		if parts.len < 9 {
			continue
		}
		iface := parts[0]
		rx := parts[6].u64()
		tx := parts[7].u64()
		handshake := parts[5].u64() // Unix timestamp; 0 = never

		mut stats := result[iface] or { TunnelStats{} }
		stats.bytes_received += rx
		stats.bytes_sent += tx
		// Mark active if a handshake has occurred (non-zero timestamp)
		if handshake > 0 {
			stats.is_active = true
		}
		result[iface] = stats
	}
	return result
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
