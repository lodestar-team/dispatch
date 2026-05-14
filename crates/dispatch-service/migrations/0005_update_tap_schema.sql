-- Migration 0002: align tap_receipts and tap_ravs with current code.
--
-- 0001 was written for an early schema that used (signer_address, chain_id) as
-- the RAV key.  The code now keys everything on the Horizon collection_id
-- (keccak256(payer || serviceProvider || dataService)) and stores the consumer
-- address separately.  Without this migration the upsert_rav / fetch_rav_floor
-- queries silently fail on a fresh deployment, which causes previous_rav_value
-- to be 0 on every aggregation cycle and breaks the GraphTallyCollector
-- monotonicity invariant.

-- tap_receipts: add payer_address and method columns if absent.
ALTER TABLE tap_receipts
    ADD COLUMN IF NOT EXISTS payer_address TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS method        TEXT;

CREATE INDEX IF NOT EXISTS tap_receipts_payer
    ON tap_receipts (payer_address);

-- tap_ravs: add Horizon fields and switch the unique key to collection_id.
ALTER TABLE tap_ravs
    ADD COLUMN IF NOT EXISTS collection_id   TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS payer_address   TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS service_provider TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS data_service    TEXT NOT NULL DEFAULT '';

-- Populate collection_id on any rows that existed before this migration so the
-- unique index below can be created without duplicates.  Rows from the old
-- schema have no meaningful collection_id; mark them so they don't collide.
UPDATE tap_ravs
   SET collection_id = concat('legacy-', id::text)
 WHERE collection_id = '';

CREATE UNIQUE INDEX IF NOT EXISTS tap_ravs_collection_id
    ON tap_ravs (collection_id);
