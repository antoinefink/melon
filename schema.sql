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

CREATE TABLE wallet_transfers (
  id TEXT NOT NULL,
  from_address TEXT,
  destination_address TEXT,
  amount TEXT NOT NULL,
  fee TEXT,

  block_height TEXT REFERENCES blocks(height) ON DELETE CASCADE,

  PRIMARY KEY(id)
);