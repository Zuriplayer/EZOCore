# EZOCore Discord automation

This document describes the GitHub Actions automation available in this repository for publishing EZOCore build status, beta builds and releases to the EZO Discord server. It only documents what is currently implemented; it does not describe planned in-game messaging.

## Overview

Three manual workflows live under `.github/workflows/`:

- `ezo-status.yml` — posts a short status card describing the current addon metadata.
- `ezo-beta.yml` — builds a clean addon ZIP and posts it as a beta build.
- `ezo-release.yml` — builds a clean addon ZIP and posts a release note, optionally also posting to the downloads and announcements channels.

All three are triggered manually from the Actions tab (`workflow_dispatch`) and never run automatically on push or on a schedule.

## Dry run by default

Every workflow exposes a `confirm_publish` input that defaults to `DRY_RUN`. Only typing the literal value `PUBLISH` causes the underlying PowerShell scripts to actually call the Discord webhooks; any other value (including the default) runs in dry-run mode, which prints the payload instead of sending it.

## Webhook secrets

The workflows read webhook URLs exclusively from GitHub Actions repository secrets, never from files committed to this repository:

- `EZO_CODEX_STATUS`
- `EZO_CODEX_BETA_BUILDS`
- `EZO_CODEX_RELEASES`
- `EZO_CODEX_DOWNLOADS`
- `EZO_CODEX_ANNOUNCER`
- `CODEX_LOG`
- `EZO_CODEX_BUG_REPORTS` (optional)

These secrets must be configured under Settings → Secrets and variables → Actions on this repository. A real webhook URL should never be pasted into code, issues, commit messages or logs.

## Scripts

The PowerShell helper scripts live under `scripts/ezo/`:

- `build-addon-package.ps1` — builds a clean, addon-store-safe ZIP based on the include/exclude rules in `ezo-addon.json`.
- `publish-discord.ps1` — shared helper that posts an embed (and optional file attachment) to a Discord webhook, or prints it when `-DryRun` is set.
- `publish-status.ps1`, `publish-beta.ps1`, `publish-release.ps1`, `publish-download.ps1`, `publish-announcement.ps1`, `publish-codex-log.ps1` — thin wrappers that build the right message for each channel and call `publish-discord.ps1`.

## Not implemented yet

This automation only publishes developer-triggered status/build/release information to Discord. It does not implement any in-game player-to-player communication, and it does not use LibGroupBroadcast. Nothing here runs automatically inside the ESO client.
