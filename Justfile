build:
    v -g -skip-unused -d mbedtls_client_read_timeout_ms=5000 .
prod:
    v -skip-unused -prod -d mbedtls_client_read_timeout_ms=5000 .
