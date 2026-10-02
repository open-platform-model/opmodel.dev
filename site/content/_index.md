---
title: Open Platform Model
description: A declarative platform model for describing applications and their infrastructure requirements.
layout: hextra-home
# The landing, in every version: the hero (text and two actions on the left,
# the landing-overview figure on the right from 64rem, after the actions on a
# phone) and three cards, with the text of the Starlight splash it replaces.
---

<div class="opm-hero">

<div class="opm-hero-main">

<div class="opm-hero-text">

<p class="opm-construction" role="note">{{< icon "exclamation" >}}<span><strong>This site is under construction.</strong> OPM is in beta: some pages are still placeholders, and any page may change without notice.</span></p>

<div class="hx:mt-6 hx:mb-6">
{{< hextra/hero-headline >}}
  Open Platform Model
{{< /hextra/hero-headline >}}
</div>

<div class="hx:mb-6">
{{< hextra/hero-subtitle >}}
  A declarative platform model for describing applications&nbsp;<br class="hx:sm:block hx:hidden" />and their infrastructure requirements.
{{< /hextra/hero-subtitle >}}
</div>

<div class="opm-hero-actions">
{{< hextra/hero-button text="Get started" link="docs/start/" >}}
{{< hextra/hero-button text="Reference" link="docs/reference/" style="background:transparent;color:inherit;box-shadow:inset 0 0 0 1px color-mix(in srgb, currentColor 22%, transparent)" >}}
</div>

</div>

<div class="opm-hero-figure">

{{< opm/landing-overview >}}

</div>

</div>

{{< hextra/feature-grid >}}
  {{< hextra/feature-card
    title="Type-safe"
    icon="badge-check"
    subtitle="CUE-based definitions, validated while you write them."
    link="docs/concepts/"
  >}}
  {{< hextra/feature-card
    title="Open source"
    icon="book-open"
    subtitle="All definitions, providers, and tooling under Apache 2.0."
    link="https://github.com/open-platform-model"
  >}}
  {{< hextra/feature-card
    title="Generated reference"
    icon="document-text"
    subtitle="Reference documentation generated from the code it describes."
    link="docs/reference/"
  >}}
{{< /hextra/feature-grid >}}

</div>
