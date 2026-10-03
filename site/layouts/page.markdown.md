{{- /* OPM override of Hextra's markdown output (v0.13.0, pinned in
       overrides.sha256), the "Copy page" and "View as Markdown" payload.
       From the page's raw Markdown it strips the planning comments
       (<!-- ... -->), points /docs/ links at this version's pages and
       /enhancements/ and /catalogs/ links at the unversioned sections
       (a /catalogs/<name>/<MAJOR>/ alias stays an alias; while the build
       has the catalog-opm tab, the two old Reference targets point at its
       alias too, as layouts/_markup/render-link.html maps them), prints a
       figure's title in place of its {{< opm/<name> >}} line (the shortcode
       means nothing outside the site), and shows an escaped shortcode as the
       page shows it. */ -}}
{{- $body := .RawContent | replaceRE `(?s)<!--.*?-->\n?` "" -}}
{{- with hugo.Data.opm.catalogs -}}{{- range .catalogs -}}{{- if eq .project "catalog-opm" -}}
  {{- $body = replaceRE `(?m)(\]\(|\]:[ \t]*)/docs/reference/catalog-contract/(#[^)\s]*)?([)\s]|$)` (printf "${1}%s${2}${3}" (absURL "catalogs/opm/4/")) $body -}}
  {{- $body = replaceRE `(?m)(\]\(|\]:[ \t]*)/docs/reference/catalog-members/(#[^)\s]*)?([)\s]|$)` (printf "${1}%s${3}" (absURL "catalogs/opm/4/#catalog-members")) $body -}}
{{- end -}}{{- end -}}{{- end -}}
{{- $body = replaceRE `(\]\(|\]:[ \t]*)/docs/` (printf "${1}%sdocs/" .Site.Home.Permalink) $body -}}
{{- $body = replaceRE `(\]\(|\]:[ \t]*)/enhancements/` (printf "${1}%s" (absURL "enhancements/")) $body -}}
{{- $body = replaceRE `(\]\(|\]:[ \t]*)/catalogs/` (printf "${1}%s" (absURL "catalogs/")) $body -}}
{{- range $name, $title := partialCached "opm/figure-titles.html" . "opm-figure-titles" -}}
  {{- $body = replaceRE (printf `(?m)^[ \t]*\{\{<[ \t]*opm/%s[ \t]*>\}\}[ \t]*$` $name) (printf "_Figure: %s_" $title) $body -}}
{{- end -}}
{{- $body = replaceRE `\{\{<[ \t]*/\*[ \t]*(.*?)[ \t]*\*/[ \t]*>\}\}` "{{< $1 >}}" $body -}}
{{- .Title | replaceRE "\n" " " | printf "# %s" }}
{{ $body | replaceRE `\n{3,}` "\n\n" }}
