# Common Impact Data Standard (CIDS)

The Common Impact Data Standard (CIDS) is an open data standard for impact data. It gives organizations a shared way to describe what they are trying to change, how they measure it, and what they found. Because the data follows one structure, it can move between software tools and be combined and compared without re-entering it by hand.

CIDS is published by [Common Approach to Impact Measurement](https://www.commonapproach.org/) as an [OWL](faq/what-is-owl.md) ontology, with [SHACL](faq/what-is-shacl.md) shapes for checking data and a [JSON-LD context](faq/context-file.md) for exchanging it.

**Who it is for**

- **Software vendors** who want their products to import and export impact data in a common format.
- **Funders** who want to collect comparable impact data from the organizations they support.
- **Social purpose organizations (SPOs)** who want to report once and share with many funders. You don't need to read this repository; see [I'm not a programmer](faq/not-a-programmer.md) and the list of [aligned software](https://www.commonapproach.org/common-impact-data-standard/).
- **Developers** building or checking a CIDS integration. Start with the [FAQ for developers](faq/README.md).

## Current version

The current version is **CIDS 3.2.1**.

- Published ontology and documentation: https://ontology.commonapproach.org/cids
- This version: https://ontology.commonapproach.org/cids/3.2.1
- JSON-LD context: https://ontology.commonapproach.org/contexts/cidsContext.jsonld
- SHACL shapes, for example the Basic tier: https://ontology.commonapproach.org/validation/shacl/cids.basictier.shacl.ttl
- Code lists: https://codelist.commonapproach.org
- Example data: https://ontology.commonapproach.org/examples/

The ontology at https://ontology.commonapproach.org/cids is the production version. The files in this repository are the source it is published from.

This repository also holds two related ontologies:

- **Social Finance Fund (SFF) companion module**, version 2.0.0, for organizations reporting to the Social Finance Fund: https://ontology.commonapproach.org/sff
- **Common Form**, version 1.0.2, which describes an organization's financial and descriptive information: https://ontology.commonapproach.org/cfo

## Related standards

CIDS is one of four standards from Common Approach: the Common Foundations, the Common Impact Data Standard, the Common Form and the Common Framework. See https://www.commonapproach.org/.

CIDS reuses terms from existing open standards rather than inventing its own, including ISO 21972 (indicators and measures), W3C PROV-O, OWL-Time, schema.org, FOAF and SKOS.

## Repository layout

| Path | What it holds |
| --- | --- |
| [`cids.ttl`](cids.ttl) | The CIDS ontology (Turtle). This is the main file. |
| [`sff.ttl`](sff.ttl) | The Social Finance Fund companion module. |
| [`cfo.ttl`](cfo.ttl), [`cfo.owl`](cfo.owl) | The Common Form ontology, in Turtle and OWL/XML. |
| [`contexts/`](contexts/) | JSON-LD context files for CIDS and SFF. |
| [`validation/shacl/`](validation/shacl/) | SHACL shapes for checking data: one file per tier (Basic, Essential, Full), one with everything (`cids.all`), plus SFF and supporting standards. |
| [`validation/sparql/`](validation/sparql/) | The SPARQL queries that generate the SHACL shapes from the ontology, one per tier. |
| [`validation/shacl-validation/`](validation/shacl-validation/) | `CIDS-validate.sh`, a script that validates a data file and summarizes the results. |
| [`faq/`](faq/) | Plain-language explainers on RDF, OWL, SHACL, JSON-LD and CIDS. |
| [`old-versions/`](old-versions/) | Earlier versions of CIDS, SFF and the Common Form. |
| [`CHANGELOG.md`](CHANGELOG.md) | Changes by version. |
| [`POLICIES.md`](POLICIES.md) | Authorship, license, availability and versioning policies. |

Example data files are published at https://ontology.commonapproach.org/examples/ rather than kept in this repository.

## Getting started: validate your data

CIDS data is usually shared as a JSON-LD file, called an Impact Data Capsule. You can check a capsule against the SHACL shapes with [Apache Jena](https://jena.apache.org/download/).

1. Install Apache Jena and make sure the `shacl` command is on your `PATH`.
2. Download the shapes file for the tier you are aligning to, for example [`cids.basictier.shacl.ttl`](https://ontology.commonapproach.org/validation/shacl/cids.basictier.shacl.ttl).
3. Download an example capsule to try, such as [`CIDSBasicZerokitsTestData-SHARED.json`](https://ontology.commonapproach.org/examples/CIDSBasicZerokitsTestData-SHARED.json), and save it with a `.jsonld` extension, for example `my-data.jsonld`. Jena uses the extension to recognize the file as JSON-LD.
4. Run:

   ```bash
   shacl validate -s cids.basictier.shacl.ttl -d my-data.jsonld > report.ttl
   ```

`report.ttl` lists anything in the data that doesn't match the standard. With the example capsule, you will see two violations on `Theme_hasCode`. They appear because the SDG codes the capsule refers to live on the code list server, not in the capsule. The [`CIDS-validate.sh`](validation/shacl-validation/README.md) script can merge in the code lists to resolve these, and it groups the results so long reports are easier to read. See [`validation/validationReadMe.md`](validation/validationReadMe.md) for how to read the results.

## Tools that work with CIDS

- [Aligned software](https://www.commonapproach.org/common-impact-data-standard/): products that can import or export CIDS data.
- [`CIDS-validate.sh`](validation/shacl-validation/README.md): validates a capsule and summarizes the results.

## How to contribute

CIDS is developed with its community, and we welcome feedback.

- **Questions, bugs and suggestions:** [open an issue](https://github.com/commonapproach/CIDS/issues).
- **Changes:** open a pull request from a branch. No one pushes directly to `main`; every change is reviewed and approved in a pull request first.

How a change to the standard is handled depends on what kind of change it is (see [Versioning](#versioning-and-changelog)):

| Change | Examples | Process |
| --- | --- | --- |
| **Patch** | Fixing typos or wording in descriptions, fixing invalid OWL syntax | A pull request, approved by a reviewer. |
| **Minor** | Adding a new class, or a new optional property | Open an issue labelled `rfc` describing the change. It stays open for comments for at least 1 week, then the change is made in a pull request. |
| **Major** | Removing or renaming a class or property, making a property required | The change is planned with the technical committee, opened as an `rfc` issue for a 60-day public consultation, then made in a pull request. |

An `rfc` issue should say what would change, which version bump it needs, and how it affects existing data and software. Every change also needs a check of what else must be updated, such as the SHACL shapes, the JSON-LD context and the documentation.

See also [How can I help with the development of the Common Impact Data Standard?](faq/how-to-help.md)

## Versioning and changelog

CIDS uses [semantic versioning](https://semver.org/), MAJOR.MINOR.PATCH:

- **Patch** (3.2.**1**): fixes that don't change what data is valid, such as corrected descriptions or OWL syntax.
- **Minor** (3.**2**.0): backwards-compatible additions, such as new classes or optional properties. Existing data stays valid.
- **Major** (**3**.0.0): changes that can make existing data invalid, such as removing a property or making one required.

Each version has its own IRI, for example `https://ontology.commonapproach.org/cids/3.2.1`, and links to the version before it. Changes are recorded in [`CHANGELOG.md`](CHANGELOG.md), and earlier versions are kept in [`old-versions/`](old-versions/). Details are in [`POLICIES.md`](POLICIES.md).

## License and contact

The Common Impact Data Standard is © 2025 Common Approach to Impact Measurement and is licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).

Contact: info@commonapproach.org
