---
title: "Catalog contract"
description: "What the opm catalog promises its users, and how a member's API version says how stable it is."
---

The opm catalog is the set of blueprints, resources and traits that every OPM platform understands. This page is the contract those members keep; the members themselves are listed below, one page each.

## Contract levels

Every member carries an API version whose level says how stable its spec is:

| Level | Promise |
| --- | --- |
| `v1` | Stable. A field is never removed or narrowed within the major. |
| `v1beta1` | Beta. A field changes only with a migration note. |
| `v1alpha1` | Alpha. Anything may change in the next minor. |

An older API version of a member stays readable on its own page while the catalog still ships it, for example [the traits](/catalogs/opm/4.4/traits/).

## Fulfilment

A member whose fulfilment is `provider` is implemented by your platform, not by this catalog. See [platforms and catalogs](/docs/concepts/) for how a platform picks its implementation.

## Catalog members

`opmodel.dev/catalogs/opm@v4` version `4.4.5`.

- [Blueprints](/catalogs/opm/4.4/blueprints/): 1
- [Resources](/catalogs/opm/4.4/resources/): 1
- [Traits](/catalogs/opm/4.4/traits/): 2
