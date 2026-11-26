---
title: Linux Fleet Management
subtitle: Architecture and implementation
author: Platform Engineering
version: 2.0
date: November 2026
cover: true
toc: true
---

# Overview

A reproducible Linux platform built with declarative configuration and GitOps.

## Configuration

```nix
{ pkgs, ... }:
{
  services.openssh.enable = true;
  environment.systemPackages = [ pkgs.git ];
}
```

> [!WARNING]
> Disk provisioning overwrites existing partitions.

| Component | Technology | Purpose |
| --- | --- | --- |
| Fleet | Clan | Provisioning |
| OS | NixOS | Configuration |
| Updates | Comin | GitOps |
| Inventory | NetBox | Asset management |

# Architecture

## Data flow

```mermaid
flowchart TD
    A[Git repository] --> B[Clan inventory]
    B --> C[NixOS configuration]
    C --> D[Workstation]
```

The inventory describes the managed machines.
