CREATE TABLE blocks (
  height BIGINT NOT NULL,
  previous_block_header_hash TEXT,
  block_header_hash TEXT,
  nonce BIGINT NOT NULL,
  time DATETIME NOT NULL,
  merkle_root TEXT NOT NULL,
  transactions TEXT NOT NULL,

  PRIMARY KEY(height)
);