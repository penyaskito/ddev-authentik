[![add-on registry](https://img.shields.io/badge/DDEV-Add--on_Registry-blue)](https://addons.ddev.com)
[![tests](https://github.com/penyaskito/ddev-authentik/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/penyaskito/ddev-authentik/actions/workflows/tests.yml?query=branch%3Amain)
[![last commit](https://img.shields.io/github/last-commit/penyaskito/ddev-authentik)](https://github.com/penyaskito/ddev-authentik/commits)
[![release](https://img.shields.io/github/v/release/penyaskito/ddev-authentik)](https://github.com/penyaskito/ddev-authentik/releases/latest)

# DDEV Authentik

## Overview

This add-on integrates the identity provider [Authentik](https://docs.goauthentik.io/docs/) into your [DDEV](https://ddev.com/) project.

## Installation

```bash
ddev add-on get penyaskito/ddev-authentik
ddev restart
```

After installation, make sure to commit the `.ddev` directory to version control.

## Usage

Authentik is served at `https://<project>.ddev.site:9443` (or
`http://<project>.ddev.site:9000`), and is reachable from the web container as
`authentik:9000`. The bootstrap admin user is `akadmin` with password `akadmin`.

> [!IMPORTANT]
> Earlier releases served Authentik on port `8142`. That port is also claimed by
> DDEV's built-in xhgui service, which made Authentik intermittently unreachable,
> so it moved to `9443`. Update any bookmarks, and any redirect URIs configured in
> applications that authenticate against your local Authentik.

| Command | Description |
| ------- | ----------- |
| `ddev describe` | View service status and used ports for Authentik |
| `ddev logs -s authentik` | Check Authentik logs |
| `ddev logs -s authentik-worker` | Check Authentik worker logs |

## Advanced Customization

To change the Authentik version:

```bash
ddev dotenv set .ddev/.env.authentik --authentik-tag=2026.5.7
ddev restart
```

Make sure to commit the `.ddev/.env.authentik` file to version control.

All customization options (use with caution):

| Variable | Flag | Default |
| -------- | ---- | ------- |
| `AUTHENTIK_TAG` | `--authentik-tag` | `2026.8.3` |
| `AUTHENTIK_POSTGRES_TAG` | `--authentik-postgres-tag` | `16-alpine` |

## Upgrading from Authentik 2024.x

Releases of this add-on before the 2026.8.3 bump shipped Authentik `2024.4.2`.
Authentik requires [sequential major-version upgrades](https://docs.goauthentik.io/install-config/upgrade/)
and blocks skips, so an existing `2024.x` database **cannot** be migrated
directly to `2026.x`. Upstream also removed Redis in `2025.10`, so the
`authentik-redis` volume is no longer used.

Since this is a local development environment, the simplest path is to reset
Authentik's state and let it bootstrap again:

```bash
# From your project directory
ddev stop
docker volume rm ddev-${DDEV_SITENAME}_authentik-pgsql \
                 ddev-${DDEV_SITENAME}_authentik-media \
                 ddev-${DDEV_SITENAME}_authentik-redis
ddev add-on get penyaskito/ddev-authentik
ddev restart
```

Replace `${DDEV_SITENAME}` with your project name, and use `docker volume ls |
grep authentik` to confirm the exact names first. Any configuration you set up
in the old Authentik instance — applications, providers, users — will be gone,
so export anything you want to keep as a
[blueprint](https://docs.goauthentik.io/customize/blueprints/) before you start.

## Credits

**Contributed and maintained by [@penyaskito](https://github.com/penyaskito). Thanks to [@Lullabot](https://github.com/lullabot) for their support!**
