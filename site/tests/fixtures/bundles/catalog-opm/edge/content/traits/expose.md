---
title: "Expose"
description: "Publishes a component's ports outside the cluster"
type: reference
---

## At a glance

| Field | Value |
| --- | --- |
| FQN | `opmodel.dev/catalogs/opm/traits/expose@v1alpha1` |
| API version | `v1alpha1`, alpha ([contract levels](/catalogs/opm/edge/#contract-levels)) |
| Module path | `opmodel.dev/catalogs/opm/traits/v1alpha1` |
| Catalog | `opmodel.dev/catalogs/opm@v4` at `main` (commit `940725124ea6`), unreleased |
| Applies to (declared) | [Volumes](/catalogs/opm/edge/resources/volumes/) |

## Spec

A component writes this trait's fields under `spec.expose`.

```cue
spec: expose: #ExposeSchema

#ExposeSchema: {
	// How often the work runs, as a cron expression.
	schedule!: string
	// The ports to publish, by name.
	ports!: [...string]
}
```

## Notes

The fields above are the whole contract; anything else a platform reads is its own extension.

## Enforcement

The spec schema is enforced by `cue` when a module is evaluated ([what enforces a rule](/docs/concepts/)).
