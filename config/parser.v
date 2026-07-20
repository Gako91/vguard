module config

import os

// WGConfig holds the data extracted from a WireGuard .conf file
pub struct WGConfig {
pub mut:
	name        string
	address     string
	private_key string
	dns         string
	public_key  string
	allowed_ips string
	endpoint    string
}

// parse_wg_config reads a .conf file and returns a populated WGConfig
pub fn parse_wg_config(file_path string) !WGConfig {
	content := os.read_file(file_path) or { return error('Cannot read configuration file') }

	mut conf := WGConfig{
		name: os.base(file_path).replace('.conf', '')
	}

	lines := content.split_into_lines()
	for line in lines {
		clean_line := line.trim_space()
		if clean_line.starts_with('#') || clean_line == '' || clean_line.starts_with('[') {
			continue
		}

		// Split on the first '=' only, so base64 values containing '=' are preserved
		sep_index := clean_line.index('=') or { continue }
		key := clean_line[..sep_index].trim_space().to_lower()
		value := clean_line[sep_index + 1..].trim_space()

		match key {
			'address' { conf.address = value }
			'privatekey' { conf.private_key = value }
			'dns' { conf.dns = value }
			'publickey' { conf.public_key = value }
			'allowedips' { conf.allowed_ips = value }
			'endpoint' { conf.endpoint = value }
			else {}
		}
	}
	return conf
}
