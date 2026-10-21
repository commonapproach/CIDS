# Changelog

## 3.2.1 (released 2025-10-31)

- 2026-10-21: Fixed invalid OWL restrictions in `cids.ttl`. Restrictions that had lost their type now use their 3.2.0 type again, the two new ones use "only", and the restriction on `rdfs:label` for `i72:Population` was removed. The release date is unchanged; the fix is recorded in `dcterms:modified`.
