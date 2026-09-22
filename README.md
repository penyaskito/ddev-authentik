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

Authentik is served at `https://<project>.ddev.site:8142`, and reachable from
the web container as `authentik:9000`. The bootstrap admin user is `akadmin`
with password `akadmin`.

| Command | Description |
| ------- | ----------- |
| `ddev describe` | View service status and used ports for Authentik |
| `ddev logs -s authentik` | Check Authentik logs |
| `ddev logs -s authentik-worker` | Check Authentik worker logs |

## Credits

**Contributed and maintained by [@penyaskito](https://github.com/penyaskito). Thanks to [@Lullabot](https://github.com/lullabot) for their support!**
