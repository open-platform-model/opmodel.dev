{{- /* OPM override of Hextra's markdown output (v0.13.0, pinned in
       overrides.sha256), the "Copy page" and "View as Markdown" payload.
       From the page's raw Markdown it strips the planning comments
       (<!-- ... -->), points /docs/ links at this version's pages and
       /enhancements/ and /catalogs/ links at the unversioned sections
       (a /catalogs/<name>/<MAJOR>/ alias stays an alias), prints a
       figure's title in place of its {{< opm/<name> >}} line (the shortcode
       means nothing outside the site), shows an escaped shortcode as the
       page shows it, and drops the "opm:removed" title of a Catalogs
       "Removed in" link (opm/history-removed.html). */ -}}
{{- $body := .RawContent | replaceRE `(?s)<!--.*?-->\n?` "" -}}
{{- $body = replaceRE `(\]\(|\]:[ \t]*)/docs/` (printf "${1}%sdocs/" .Site.Home.Permalink) $body -}}
{{- $body = replaceRE `(\]\(|\]:[ \t]*)/enhancements/` (printf "${1}%s" (absURL "enhancements/")) $body -}}
{{- $body = replaceRE `(\]\(|\]:[ \t]*)/catalogs/` (printf "${1}%s" (absURL "catalogs/")) $body -}}
{{- $body = replaceRE `(\]\([^ )]*) "opm:removed"\)` "${1})" $body -}}
{{- range $name, $title := partialCached "opm/figure-titles.html" . "opm-figure-titles" -}}
  {{- $body = replaceRE (printf `(?m)^[ \t]*\{\{<[ \t]*opm/%s[ \t]*>\}\}[ \t]*$` $name) (printf "_Figure: %s_" $title) $body -}}
{{- end -}}
{{- $body = replaceRE `\{\{<[ \t]*/\*[ \t]*(.*?)[ \t]*\*/[ \t]*>\}\}` "{{< $1 >}}" $body -}}
{{- .Title | replaceRE "\n" " " | printf "# %s" }}
{{ $body | replaceRE `\n{3,}` "\n\n" }}
