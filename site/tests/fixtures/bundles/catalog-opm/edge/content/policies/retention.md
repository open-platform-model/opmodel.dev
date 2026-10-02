---
title: "Retention"
description: "How long a platform keeps what a component leaves behind"
type: reference
---

## At a glance

| Field | Value |
| --- | --- |
| FQN | `opmodel.dev/catalogs/opm/policies/retention@v1alpha1` |
| API version | `v1alpha1`, alpha ([contract levels](/catalogs/opm/edge/#contract-levels)) |
| Module path | `opmodel.dev/catalogs/opm/policies/v1alpha1` |
| Catalog | `opmodel.dev/catalogs/opm@v4` at `main` (commit `940725124ea6`), unreleased |

## Spec

A component writes this policie's fields under `spec.retention`.

```cue
spec: retention: #RetentionSchema

#RetentionSchema: {
	// How often the work runs, as a cron expression.
	schedule!: string
}
```

## Notes

The fields above are the whole contract; anything else a platform reads is its own extension.

## Enforcement

The spec schema is enforced by `cue` when a module is evaluated ([what enforces a rule](/docs/concepts/)).
