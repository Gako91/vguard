module config

import crypto.aes
import encoding.base64
import os

// derive_machine_key builds a deterministic 16-byte AES key from
// the current user + hostname so that the stored private keys are
// opaque to casual inspection without requiring a password prompt.
fn derive_machine_key() []u8 {
	user := os.getenv('USER')
	hostname := os.execute('hostname').output.trim_space()
	raw := '${user}@${hostname}-vguard-key'
	mut key := []u8{len: 16, init: 0}
	for i, b in raw.bytes() {
		key[i % 16] ^= b
	}
	return key
}

// pkcs7_pad pads `data` to a multiple of `block_size` using PKCS#7.
fn pkcs7_pad(data []u8, block_size int) []u8 {
	pad_len := block_size - (data.len % block_size)
	mut padded := data.clone()
	for _ in 0 .. pad_len {
		padded << u8(pad_len)
	}
	return padded
}

// pkcs7_unpad removes PKCS#7 padding. Returns an empty slice on invalid data.
fn pkcs7_unpad(data []u8) []u8 {
	if data.len == 0 {
		return []
	}
	pad_len := int(data[data.len - 1])
	if pad_len == 0 || pad_len > 16 || pad_len > data.len {
		return data // not padded — return as-is
	}
	return data[..data.len - pad_len]
}

// encrypt_key encrypts a plain-text WireGuard private key with AES-128 ECB
// and returns a base64-encoded cipher string prefixed with "enc:".
// If encryption fails for any reason, returns the original plain text.
pub fn encrypt_key(plain string) string {
	if plain == '' {
		return plain
	}
	// Don't double-encrypt
	if plain.starts_with('enc:') {
		return plain
	}
	key := derive_machine_key()
	cipher_block := aes.new_cipher(key)
	padded := pkcs7_pad(plain.bytes(), 16)
	mut encrypted := []u8{len: padded.len}
	// ECB mode: encrypt each 16-byte block independently
	for i := 0; i + 16 <= padded.len; i += 16 {
		cipher_block.encrypt(mut encrypted[i..i + 16], padded[i..i + 16])
	}
	return 'enc:' + base64.encode(encrypted)
}

// decrypt_key decrypts a value previously encrypted by encrypt_key.
// If the value does not start with "enc:", it is returned unchanged
// (backward compatibility with plain-text tunnels.json files).
pub fn decrypt_key(stored string) string {
	if !stored.starts_with('enc:') {
		return stored // legacy plain-text value
	}
	b64_part := stored[4..] // strip "enc:" prefix
	encrypted := base64.decode(b64_part)
	if encrypted.len == 0 || encrypted.len % 16 != 0 {
		return stored // corrupt data — return raw to avoid panic
	}
	key := derive_machine_key()
	cipher_block := aes.new_cipher(key)
	mut decrypted := []u8{len: encrypted.len}
	for i := 0; i + 16 <= encrypted.len; i += 16 {
		cipher_block.decrypt(mut decrypted[i..i + 16], encrypted[i..i + 16])
	}
	unpadded := pkcs7_unpad(decrypted)
	return unpadded.bytestr()
}
