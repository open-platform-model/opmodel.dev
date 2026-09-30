{{- /* OPM override of Hextra's markdown output (v0.13.0, pinned in
       overrides.sha256): the "Copy page" payload strips the planning
       comments (<!-- ... -->) that source pages carry. */ -}}
{{- .Title | replaceRE "\n" " " | printf "# %s" }}
{{ .RawContent | replaceRE `(?s)<!--.*?-->\n?` "" | replaceRE `\n{3,}` "\n\n" }}
