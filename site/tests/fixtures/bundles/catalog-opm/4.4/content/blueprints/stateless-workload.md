---
title: "Stateless workload"
description: "A replicated workload that keeps no state of its own"
type: reference
---

## At a glance

| Field | Value |
| --- | --- |
| FQN | `opmodel.dev/catalogs/opm/blueprints/stateless-workload@v1` |
| API version | `v1`, stable ([contract levels](/catalogs/opm/4.4/#contract-levels)) |
| Module path | `opmodel.dev/catalogs/opm/blueprints/v1` |
| Catalog | `opmodel.dev/catalogs/opm@v4` version `4.4.5` |

## Spec

A component writes this blueprint's fields under `spec.statelessworkload`.

```cue
spec: statelessworkload: #StatelessworkloadSchema

#StatelessworkloadSchema: {
	// How often the work runs, as a cron expression.
	schedule!: string
}
```

## Notes

The fields above are the whole contract; anything else a platform reads is its own extension.

## Enforcement

The spec schema is enforced by `cue` when a module is evaluated ([what enforces a rule](/docs/concepts/)).
