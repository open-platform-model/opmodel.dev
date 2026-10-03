---
title: "Backup"
description: "Scheduled backup policy for a component's persistent state"
type: reference
---

## At a glance

| Field | Value |
| --- | --- |
| FQN | `opmodel.dev/catalogs/opm/traits/backup@v1alpha2` |
| API version | `v1alpha2`, alpha ([contract levels](/catalogs/opm/4.5/#contract-levels)) |
| Module path | `opmodel.dev/catalogs/opm/traits/v1alpha2` |
| Catalog | `opmodel.dev/catalogs/opm@v4` version `4.5.0` |
| Applies to (declared) | [Volumes](/catalogs/opm/4.5/resources/volumes/) |

## Spec

A component writes this trait's fields under `spec.backup`.

```cue
import "opmodel.dev/catalogs/opm/schemas"

spec: backup: #BackupSchema

#BackupSchema: {
	// How often the work runs, as a cron expression.
	schedule!: schemas.#CronSchema
	// How many copies to keep.
	keep: *14 | int
	// Where the copies go.
	target!: {...}
	// Which volumes to capture, by name. Absent: all of them.
	volumes?: [...string]
}
```

## Notes

The fields above are the whole contract; anything else a platform reads is its own extension.

## Enforcement

The spec schema is enforced by `cue` when a module is evaluated ([what enforces a rule](/docs/concepts/)).
