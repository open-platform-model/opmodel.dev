---
title: "Enhancements"
description: "The fixture design record."
---

| ID | Category | Affects | Status | Progress | Breaking | Title | Summary |
| -- | -------- | ------- | ------ | -------- | -------- | ----- | ------- |
| [0026](/enhancements/0026/) | schema | core, library, cli, opm-operator, catalog | accepted | 2 of 5 | yes | Module-Dictated Catalog Versions and the Generated Platform | Let a platform admit a catalog path with a version range. |
| [0042](/enhancements/0042/) | runtime | cli, catalog_opm, .github | draft | - | - | Fixture No Specs | A draft without a delta spec. |

## Archived (delivered / rejected / superseded / withdrawn)

| ID | Category | Status | Title | Summary | Why closed |
| -- | -------- | ------ | ----- | ------- | ---------- |
| [0001](/enhancements/0001/) | schema | draft | Fixture Live Entry | A live draft entry of the fixture workspace. | - |
| [0002](/enhancements/0002/) | tooling | delivered | Fixture Archived Entry | An archived entry of the fixture workspace. | delivered (1 landing) |
| [0003](/enhancements/0003/) | distribution | superseded | Module Publishing Workflow | Bind a module's identity fields to one registry path. | superseded by [0025](/enhancements/0025/) |
| [0025](/enhancements/0025/) | schema | draft | Self-Describing Modules | A legacy draft kept in the archive. | - |
| [0040](/enhancements/0040/) | runtime | delivered | Fixture Delivered | A delivered entry. | delivered 2026-10-21 |
| [0041](/enhancements/0041/) | runtime | rejected | Fixture Rejected | A rejected entry. | A fixture reason. |
| [0043](/enhancements/0043/) | runtime | withdrawn | Fixture Withdrawn | A withdrawn entry. | A fixture reason. |
| [0044](/enhancements/0044/) | runtime | superseded | Fixture Superseded | A superseded entry. | superseded by [0026](/enhancements/0026/) and [0040](/enhancements/0040/) |

## Capabilities

| Capability | Requirements | Purpose |
| ---------- | ------------ | ------- |
| [registration-acceptance](/enhancements/capabilities/registration-acceptance/) | 1 | Decide whether a provider's claim is accepted. |
| [single-build-render](/enhancements/capabilities/single-build-render/) | 1 | The render path as one CUE build per render. |

How they relate: [the relationship graph](/enhancements/graph/).
