CREATE TABLE blocks (
  height BIGINT NOT NULL,
  previous_block_hash TEXT,
  nonce BIGINT NOT NULL,
  time DATETIME NOT NULL,
  block_hash TEXT NOT NULL,

  PRIMARY KEY(height)
);