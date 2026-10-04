---
title: Dialect
description: Every alert type with a bold title, and CUE empty strings.
type: reference
---

> [!NOTE]
> **Note title**
>
> The note body.

> [!TIP]
> **Tip title**
>
> The tip body.

> [!IMPORTANT]
> **Important title**
>
> The important body.

> [!WARNING]
> **Warning title**
>
> The warning body.

> [!CAUTION]
> **Caution title**
>
> The caution body.

```cue
#config: {
	image:    string | *""
	replicas: int | *1
	labels: [string]: string | *""
	name:     string
}
```
