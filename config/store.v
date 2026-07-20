module config

import json2
import os

// store_path returns the path to the persistent tunnels JSON file
fn store_path() string {
	home := os.home_dir()
	dir := os.join_path(home, '.config', 'vguard')
	os.mkdir_all(dir) or {}
	return os.join_path(dir, 'tunnels.json')
}

// StoredTunnel is a serialisable snapshot of a tunnel configuration
pub struct StoredTunnel {
pub mut:
	name        string
	address     string
	private_key string
	dns         string
	public_key  string
	allowed_ips string
	endpoint    string
}

// wg_config_to_stored converts a WGConfig to a StoredTunnel
pub fn wg_config_to_stored(c WGConfig) StoredTunnel {
	return StoredTunnel{
		name:        c.name
		address:     c.address
		private_key: c.private_key
		dns:         c.dns
		public_key:  c.public_key
		allowed_ips: c.allowed_ips
		endpoint:    c.endpoint
	}
}

// stored_to_wg_config converts a StoredTunnel back to a WGConfig
pub fn stored_to_wg_config(s StoredTunnel) WGConfig {
	return WGConfig{
		name:        s.name
		address:     s.address
		private_key: s.private_key
		dns:         s.dns
		public_key:  s.public_key
		allowed_ips: s.allowed_ips
		endpoint:    s.endpoint
	}
}

// save_tunnels persists the tunnel list to disk as JSON.
// The private_key field is encrypted with AES-128 before writing.
pub fn save_tunnels(tunnels []WGConfig) {
	mut stored := tunnels.map(wg_config_to_stored(it))
	for mut s in stored {
		s.private_key = encrypt_key(s.private_key)
	}
	data := json2.encode(stored)
	os.write_file(store_path(), data) or {}
}

// load_tunnels reads the persisted tunnel list from disk.
// The private_key field is decrypted transparently (falls back to plain text
// for files written before the encryption feature was added).
pub fn load_tunnels() []WGConfig {
	data := os.read_file(store_path()) or { return [] }
	mut stored := json2.decode[[]StoredTunnel](data) or { return [] }
	for mut s in stored {
		s.private_key = decrypt_key(s.private_key)
	}
	return stored.map(stored_to_wg_config(it))
}
