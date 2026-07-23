-- =============================================================================
-- Milestone 2.5 — Optimization
-- Refreshes statistics on the warehouse tables. Run after a large backfill
-- or incremental batch, in addition to (not instead of) auto-update stats.
-- If sp_updatestats isn't available on your Synapse dedicated pool tier,
-- replace this with explicit UPDATE STATISTICS <table> WITH FULLSCAN calls
-- per dim/fact table instead.
-- =============================================================================

USE [AdeaDW];
GO

EXEC sp_updatestats;
GO
