# PITHOS Workbench Continuity Layer

A zero-install, synthetic reference implementation of PITHOS command-triggered continuity retrieval.

The demo shows how a durable file tree can:

1. receive a context-dependent user command;
2. select an explicit continuity route;
3. retrieve the smallest sufficient approved record set;
4. exclude stale, restricted, and unrelated records;
5. bind provenance to the answer;
6. reuse an existing mount for a duplicate request; and
7. emit an inspectable receipt.

## Build Week Boundary

PITHOS existed before OpenAI Build Week. This portable implementation represents the post-cutoff Workbench Continuity Layer extension. The broader private PITHOS archive and pre-existing role architecture are not included or claimed as new work.

## Zero-Install Quick Start

### Browser demonstration

Open **index.html** in a current browser.

No server, package manager, account, network connection, or installation is required. Click **Run request** to execute the synthetic continuity flow. Click it again to display duplicate-request mount reuse.

### Tested router

On Windows 10 or 11, from this directory:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\verify_demo.ps1

Expected result:

    "status": "PASS"
    "assertions": 11

To generate a fresh receipt and answer:

    powershell -NoProfile -ExecutionPolicy Bypass -File .\run_demo.ps1

Generated files:

- output\receipt_latest.json
- output\answer_latest.md

The scripts use Windows PowerShell 5.1 built-ins only. They install nothing, modify no startup settings, create no scheduled tasks, and make no network requests.

## Portable File Tree

    portable_demo\
    |-- index.html
    |-- styles.css
    |-- app.js
    |-- pithos_router.ps1
    |-- run_demo.ps1
    |-- verify_demo.ps1
    |-- verify_package.ps1
    |-- README.md
    |-- LICENSE
    |-- HOST_PORTABILITY.md
    |-- MANIFEST.sha256
    |-- data\
    |   |-- routes.json
    |   +-- records.json
    +-- output\
        |-- receipt_latest.json
        |-- answer_latest.md
        |-- verification_latest.json
        +-- package_verification_latest.json

## Demonstrated Invariants

- **Bounded retrieval:** exactly two records satisfy the route.
- **Freshness:** the stale decision is excluded.
- **Permission binding:** the restricted incident is excluded.
- **Route isolation:** the unrelated Orbit record is excluded.
- **Provenance:** every mounted record retains its source path and effective time.
- **Idempotence:** a duplicate request reuses the in-memory mount.
- **Privacy:** all records are fictional and synthetic.

**verify_demo.ps1** contains explicit assertions for these behaviors. **verify_package.ps1** also checks required files, JSON validity, source hashes, DOM references, browser/core record alignment, and the absence of network, installation, startup, or service calls.

## Architecture

The file tree is the durable layer. Models and hosts are replaceable execution surfaces.

- data\records.json freezes synthetic source records.
- data\routes.json defines the retrieval contract.
- pithos_router.ps1 applies routing, scope, freshness, selection, and deduplication.
- output\receipt_latest.json records the state transition and exclusions.
- output\answer_latest.md binds the answer to provenance.
- index.html provides a visual inspection and video-recording surface.

## Model And Host Boundary

The portable reference implementation was built in Codex using GPT-5.6 Sol at max effort. Earlier competition packet preparation in the same long-lived Genesis archive used Sol at xhigh. The qualifying `/feedback` ID remains a separate submission field. PITHOS does not depend on model identity for durable continuity.

This reference implementation is intentionally low-resource because the current development host cannot safely absorb new toolchain installations. The frozen bundle passes verification after extraction into a new directory on the current host. Execution on a second physical host, future server migration, and cross-host persistence are not yet claimed.

## Privacy And Safety

The demo contains no private PITHOS archive material, personal JSONL, medical or family data, credentials, employer records, or external integrations. It is safe to inspect and record locally.

## Current Limitations

- The browser surface mirrors the tested routing behavior but does not read the private PITHOS tree.
- The PowerShell cache is process-local.
- The frozen bundle passes a clean-directory extraction test on the current host; a second physical host and cross-host migration are not yet verified.
- No repository has been published.
- No external plugin or source tool is required.
- Final Build Week feedback ID, video, and repository evidence remain separate submission steps.

## License

MIT. See **LICENSE**.

