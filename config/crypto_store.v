module config

import crypto.aes
import crypto.cipher
import crypto.rand
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

// derive_machine_key_256 builds a deterministic 32-byte AES key for AES-256
fn derive_machine_key_256() []u8 {
	user := os.getenv('USER')
	hostname := os.execute('hostname').output.trim_space()
	raw := '${user}@${hostname}-vguard-key-v2-aes256'
	mut key := []u8{len: 32, init: 0}
	for i, b in raw.bytes() {
		key[i % 32] ^= b
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

// encrypt_key encrypts a plain-text WireGuard private key with AES-256 CFB mode
// and a 16-byte random IV. Returns a base64-encoded cipher string prefixed with "enc:v2:".
// Fallback to raw string if random generation fails.
pub fn encrypt_key(plain string) string {
	if plain == '' {
		return plain
	}
	// Don't double-encrypt
	if plain.starts_with('enc:') || plain.starts_with('enc:v2:') {
		return plain
	}
	key := derive_machine_key_256()
	cipher_block := aes.new_cipher(key)
	iv := rand.bytes(16) or { return plain }
	mut cfb := cipher.new_cfb_encrypter(cipher_block, iv)
	plain_bytes := plain.bytes()
	mut encrypted := []u8{len: plain_bytes.len}
	cfb.xor_key_stream(mut encrypted, plain_bytes)

	mut payload := []u8{cap: 16 + encrypted.len}
	payload << iv
	payload << encrypted
	return 'enc:v2:' + base64.encode(payload)
}

// decrypt_key decrypts a value previously encrypted by encrypt_key.
// Supports both "enc:v2:" (AES-256 CFB with random IV) and "enc:" (legacy AES-128 ECB).
// If the value does not start with "enc:", it is returned unchanged.
pub fn decrypt_key(stored string) string {
	if stored.starts_with('enc:v2:') {
		b64_part := stored[7..]
		payload := base64.decode(b64_part)
		if payload.len < 16 {
			return stored
		}
		iv := payload[..16]
		encrypted := payload[16..]
		key := derive_machine_key_256()
		cipher_block := aes.new_cipher(key)
		mut cfb := cipher.new_cfb_decrypter(cipher_block, iv)
		mut decrypted := []u8{len: encrypted.len}
		cfb.xor_key_stream(mut decrypted, encrypted)
		return decrypted.bytestr()
	}
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
