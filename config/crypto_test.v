module config

fn test_crypto_store() {
	secret := 'd3V3dzM0NTY3ODkwMTIzNDU2Nzg5MDEyMzQ1Njc4OTA='
	encrypted := encrypt_key(secret)
	assert encrypted.starts_with('enc:v2:')
	decrypted := decrypt_key(encrypted)
	assert decrypted == secret

	// Test legacy plain text
	plain := 'plain_text_key'
	assert decrypt_key(plain) == plain

	// Test double-encrypt prevention
	assert encrypt_key(encrypted) == encrypted
}
