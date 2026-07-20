module config

import os

// Helpers to create temporary .conf files during tests

fn tmp_conf(content string) string {
	path := os.join_path(os.temp_dir(), 'vguard_test_${rand_name()}.conf')
	os.write_file(path, content) or { panic('cannot write tmp conf: ${err}') }
	return path
}

fn rand_name() string {
	return '${os.getpid()}_${u64(os.file_last_mod_unix(os.executable()))}'
}

fn cleanup(path string) {
	os.rm(path) or {}
}

// -----------------------------------------------------------------------
// parse_wg_config tests
// -----------------------------------------------------------------------

fn test_parse_full_config() {
	conf_content := '[Interface]
Address = 10.0.0.2/24
PrivateKey = abc123base64privatekey==
DNS = 1.1.1.1

[Peer]
PublicKey = xyz789base64publickey==
AllowedIPs = 0.0.0.0/0
Endpoint = vpn.example.com:51820
'
	path := tmp_conf(conf_content)
	defer { cleanup(path) }

	conf := parse_wg_config(path) or { panic('parse failed: ${err}') }

	assert conf.name == os.base(path).replace('.conf', '')
	assert conf.address == '10.0.0.2/24'
	assert conf.private_key == 'abc123base64privatekey=='
	assert conf.dns == '1.1.1.1'
	assert conf.public_key == 'xyz789base64publickey=='
	assert conf.allowed_ips == '0.0.0.0/0'
	assert conf.endpoint == 'vpn.example.com:51820'
}

fn test_parse_minimal_config() {
	// Only the bare minimum fields
	conf_content := '[Interface]
PrivateKey = minimalkey==
Address = 192.168.1.5/32

[Peer]
PublicKey = peerkey==
'
	path := tmp_conf(conf_content)
	defer { cleanup(path) }

	conf := parse_wg_config(path) or { panic('parse failed: ${err}') }

	assert conf.private_key == 'minimalkey=='
	assert conf.address == '192.168.1.5/32'
	assert conf.public_key == 'peerkey=='
	// Optional fields should be empty
	assert conf.dns == ''
	assert conf.endpoint == ''
	assert conf.allowed_ips == ''
}

fn test_parse_base64_with_multiple_equals() {
	// Base64-encoded WireGuard keys often end with one or two '='
	// The parser must NOT split on the extra '=' in the value
	priv := 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
	pub_k := 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB='
	conf_content := '[Interface]
PrivateKey = ${priv}
Address = 10.1.0.1/24

[Peer]
PublicKey = ${pub_k}
AllowedIPs = 10.0.0.0/8
'
	path := tmp_conf(conf_content)
	defer { cleanup(path) }

	conf := parse_wg_config(path) or { panic('parse failed: ${err}') }

	assert conf.private_key == priv, 'private_key base64 with = was truncated'
	assert conf.public_key == pub_k, 'public_key base64 with = was truncated'
}

fn test_parse_comments_and_sections_ignored() {
	// Lines starting with '#' or '[' must be silently ignored
	conf_content := '# This is a comment
[Interface]
# Another comment
Address = 172.16.0.1/16
PrivateKey = commenttest==

[Peer]
# Peer comment
PublicKey = peerkeycomment==
AllowedIPs = 0.0.0.0/0
'
	path := tmp_conf(conf_content)
	defer { cleanup(path) }

	conf := parse_wg_config(path) or { panic('parse failed: ${err}') }

	assert conf.address == '172.16.0.1/16'
	assert conf.private_key == 'commenttest=='
	assert conf.public_key == 'peerkeycomment=='
}

fn test_parse_whitespace_trimmed() {
	// Keys and values with extra whitespace should be trimmed
	conf_content := '[Interface]
  Address   =   10.2.2.2/24   
  PrivateKey   =   trimmedkey==   

[Peer]
  PublicKey   =   trimmedpubkey==   
'
	path := tmp_conf(conf_content)
	defer { cleanup(path) }

	conf := parse_wg_config(path) or { panic('parse failed: ${err}') }

	assert conf.address == '10.2.2.2/24'
	assert conf.private_key == 'trimmedkey=='
	assert conf.public_key == 'trimmedpubkey=='
}

fn test_parse_missing_file_returns_error() {
	non_existent := '/tmp/vguard_does_not_exist_xyz.conf'
	_ := parse_wg_config(non_existent) or {
		// Expected: function must return an error
		assert err.msg() != '', 'error message should not be empty'
		return
	}
	assert false, 'parse_wg_config should have returned an error for a missing file'
}

fn test_parse_empty_file() {
	path := tmp_conf('')
	defer { cleanup(path) }

	conf := parse_wg_config(path) or { panic('parse failed: ${err}') }

	// All fields should be empty strings
	assert conf.address == ''
	assert conf.private_key == ''
	assert conf.public_key == ''
}

// -----------------------------------------------------------------------
// encrypt_key / decrypt_key round-trip tests
// -----------------------------------------------------------------------

fn test_encrypt_decrypt_roundtrip() {
	plain := 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
	encrypted := encrypt_key(plain)
	assert encrypted.starts_with('enc:'), 'encrypted value must start with "enc:"'
	decrypted := decrypt_key(encrypted)
	assert decrypted == plain, 'round-trip failed: got "${decrypted}" want "${plain}"'
}

fn test_encrypt_does_not_double_encrypt() {
	plain := 'singleencryptkey=='
	encrypted := encrypt_key(plain)
	double := encrypt_key(encrypted)
	assert double == encrypted, 'encrypt_key must not re-encrypt an already-encrypted value'
}

fn test_decrypt_legacy_plain_text() {
	// Values without the "enc:" prefix must be returned unchanged (backward compat)
	plain := 'legacyplaintextkey=='
	result := decrypt_key(plain)
	assert result == plain, 'decrypt_key must pass through plain-text values unchanged'
}

fn test_encrypt_empty_string() {
	// Empty private keys must not be encrypted (no-op)
	assert encrypt_key('') == ''
	assert decrypt_key('') == ''
}
