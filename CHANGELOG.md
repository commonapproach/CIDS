# Changelog

## 3.2.1 (released 2025-10-31)

- 2026-10-21: Fixed invalid OWL restrictions in `cids.ttl`. Restrictions that had lost their type now use the type they had before it was removed, restrictions whose cardinality had been deliberately removed now use "only", and the restriction on `rdfs:label` for `i72:Population` was removed. The release date is unchanged; the fix is recorded in `dcterms:modified`.
- 2026-10-22: Follow-up fixes. `foaf:formerName` and the `StakeholderReport` start and end times are now optional ("only" instead of "some"), matching the SHACL. The `hasIdentifier` restriction on each of the 9 ImpactRisk subclasses is split into a valid "exactly 1" and a "has value" restriction. Removed the `rdfs:Label` typo and the redeclaration of `owl:qualifiedCardinality` as an annotation property. In the JSON-LD context, `hasLegalStatus` now links to an IRI. In the SHACL, removed `sh:maxCount 0` (which forbade optional properties) and fixed the queries that produced it, converted `SDGImpacts.shacl.ttl` to UTF-8, and removed a generator output file that contained only an error message.
