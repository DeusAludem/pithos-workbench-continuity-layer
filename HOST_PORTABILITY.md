# Host Portability Requirement

Status: clean-directory verified / second physical host unproven

## Why It Matters

The current PITHOS development laptop is resource-constrained and showing signs of increasing startup and reliability pressure. Adding new language runtimes, package managers, background services, or startup tasks is outside the safe scope of this competition build.

PITHOS therefore treats the durable file tree as the continuity substrate. A future mini PC or other server host should be able to receive the indexed records, route contracts, pointers, receipts, and tests without changing the conceptual architecture.

## Current Evidence

- This demo requires no installation.
- The browser surface runs from static files.
- The tested router uses Windows PowerShell 5.1 built-ins only.
- No network call, scheduled task, service, or startup modification is used.
- All source and generated evidence remains inside one portable directory.
- The frozen bundle extracts into a new directory on the current host and passes the full package verifier there.

## Not Yet Proven

- Execution on a second physical Windows host.
- Migration to a mini PC or dedicated server.
- Cross-host continuity persistence.
- Recovery behavior after hardware loss.

These remain future test gates and must not be represented as completed capabilities in the competition submission.
