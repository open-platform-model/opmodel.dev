---
title: Quickstart
description: The fixture tutorial, with alerts, links and a CUE block.
type: tutorial
weight: 3
---

A short tutorial page that exercises the page dialect.

> [!TIP]
> **Deploying your own module**
>
> Replace the example module with your own; the steps stay the same.

> [!NOTE]
> **Two paragraphs**
>
> The first paragraph of the note.
>
> The second paragraph, with a list:
>
> - one item
> - another item

Read why in [the fixture concept](/docs/concepts/fixture-concept/#why), then go back to [the start section][start].

## A CUE block

```cue
#config: {
	image:    string | *""
	replicas: int | *1
}
```

[start]: /docs/start/
