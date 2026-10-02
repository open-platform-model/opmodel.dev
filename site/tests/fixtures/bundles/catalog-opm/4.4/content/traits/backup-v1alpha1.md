---
title: "Backup (v1alpha1)"
description: "The first backup policy, kept while 4.4 still ships it"
type: reference
---

## At a glance

| Field | Value |
| --- | --- |
| FQN | `opmodel.dev/catalogs/opm/traits/backup@v1alpha1` |
| API version | `v1alpha1`, alpha ([contract levels](/catalogs/opm/4.4/#contract-levels)) |
| Module path | `opmodel.dev/catalogs/opm/traits/v1alpha1` |
| Catalog | `opmodel.dev/catalogs/opm@v4` version `4.4.5` |
| Applies to (declared) | [Volumes](/catalogs/opm/4.4/resources/volumes/) |

## Spec

A component writes this trait's fields under `spec.backup`.

```cue
spec: backup: #BackupSchema

#BackupSchema: {
	// How often the work runs, as a cron expression.
	schedule!: string
}
```

## Notes

Superseded by the `v1alpha2` page of the same name.

## Enforcement

The spec schema is enforced by `cue` when a module is evaluated ([what enforces a rule](/docs/concepts/)).
