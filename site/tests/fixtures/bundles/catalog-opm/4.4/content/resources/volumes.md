---
title: "Volumes"
description: "Persistent and ephemeral storage a component mounts"
type: reference
---

## At a glance

| Field | Value |
| --- | --- |
| FQN | `opmodel.dev/catalogs/opm/resources/volumes@v1beta1` |
| API version | `v1beta1`, beta ([contract levels](/catalogs/opm/4.4/#contract-levels)) |
| Module path | `opmodel.dev/catalogs/opm/resources/v1beta1` |
| Catalog | `opmodel.dev/catalogs/opm@v4` version `4.4.5` |

## Spec

A component writes this resource's fields under `spec.volumes`.

```cue
spec: volumes: #VolumesSchema

#VolumesSchema: {
	// How often the work runs, as a cron expression.
	schedule!: string
	// The size of the volume, in bytes or with a unit suffix.
	size?: string
}
```

## Notes

The fields above are the whole contract; anything else a platform reads is its own extension.

## Enforcement

The spec schema is enforced by `cue` when a module is evaluated ([what enforces a rule](/docs/concepts/)).
