-- Returns & Refunds table
-- Run this once against your PostgreSQL database.
-- The server will also attempt CREATE TABLE IF NOT EXISTS on startup via routes/returns.js

CREATE TABLE IF NOT EXISTS returns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id),
  user_id UUID NOT NULL REFERENCES users(id),
  reason VARCHAR(200) NOT NULL,
  comments TEXT,
  images TEXT[],
  status VARCHAR(30) DEFAULT 'requested' CHECK (status IN (
    'requested','approved','rejected','picked_up','refunded','completed'
  )),
  admin_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS returns_order_id_idx ON returns(order_id);
CREATE INDEX IF NOT EXISTS returns_user_id_idx  ON returns(user_id);
CREATE INDEX IF NOT EXISTS returns_status_idx   ON returns(status);

-- Backward-compat columns on orders table (used by the legacy return endpoint)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS return_reason TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS return_notes  TEXT;
