# Tests

`run-tests.sh` checks the files in this repository. GitHub Actions runs it on every pull request and every push to `main` (see [`.github/workflows/validate.yml`](../.github/workflows/validate.yml)). For how to run it on your own computer, see [Running the tests](../README.md#running-the-tests) in the main README.

## What is in this folder

| Path | What it is |
| --- | --- |
| `run-tests.sh` | Runs all the checks and prints `PASS`, `FAIL`, `KNOWN` or `SKIP` for each one. |
| `known-failures.txt` | Checks that already fail on `main`, each with a link to its issue. |
| `known-owl-problems/` | For each ontology file, the OWL 2 DL problems ROBOT reports today. |
| `samples/<tier>/valid/` | Capsules that must pass the SHACL shapes for that tier and every tier below it. |
| `samples/<tier>/invalid/` | Capsules that are each broken in one way, with a `.expected` file saying how. |
| `lib/results.rq` | The query that turns a SHACL report into one line per problem. |
| `catalog-v001.xml` | Tells ROBOT to use this repository's `cids.ttl` when an ontology imports CIDS. |

The tiers are `basic`, `essential` and `full`, matching `validation/shacl/cids.<tier>tier.shacl.ttl`.

## The samples

The samples are JSON-LD capsules for a made-up organization, Green Meals Co-operative. They use the context in this repository (`contexts/cidsContext.jsonld`), so a change to the context is tested too. Properties that are not in the context yet are written with their prefix, for example `"cids:forTarget"`.

### Adding a valid sample

Put the `.jsonld` file in `samples/<tier>/valid/`. It must give no problems at all, not even warnings or info, against its tier and every tier below it.

### Adding a broken sample

1. Put the `.jsonld` file in `samples/<tier>/invalid/`. Break only one thing, and keep the rest of the file valid, so the test shows exactly what it is about.
2. Add a `.expected` file with the same name, listing the problems it must produce, one per line, as `<property> <constraint>`. For example:

   ```
   hasLegalName MinCount
   ```

   The constraint is the SHACL constraint name without `ConstraintComponent`: `MinCount`, `MaxCount`, `Datatype`, `Class`, `NodeKind` and so on.

The test fails if the sample produces anything other than exactly these problems. That way a sample that fails for the wrong reason, such as a broken context, doesn't count as a pass.

## Known failures

Checks that fail on `main` and have an open issue are listed in `known-failures.txt` as `<check name>  <issue link>`. The check name is exactly what `run-tests.sh` prints after `FAIL`. Listed checks are reported as `KNOWN` and don't fail the run.

When you fix one of these, the check starts passing and the run fails with "now passes". Delete its line in the same pull request as the fix. This keeps the list from going out of date.

Don't add a line just to make a pull request pass. A new failure should be fixed, or have its own issue opened and agreed first.

## Known OWL problems

The ontologies don't fully follow the OWL 2 DL rules yet. Some problems are in our own files, and many come from the ontologies CIDS imports, such as OWL-Time and ISO 21972. Listing `owl-dl cids.ttl` as a known failure would hide any new problem, so each file has its own list instead, in `known-owl-problems/<file>.txt`. That list is exactly what ROBOT reports today.

- A pull request that **adds** a problem fails, and the run shows the new problem.
- A pull request that **fixes** a problem also fails, with "Fixed ... of the problems". Run `tests/run-tests.sh --update-owl-lists` and commit the updated list. The list's diff then shows reviewers exactly what was fixed.

Don't edit these lists by hand. The issues for the problems in our own files are listed at the end of `known-failures.txt`.

The OWL checks load the imported ontologies from the web, so they need internet access. If an imported ontology's server is down, or its owners change it, the OWL checks can fail even though nothing in this repository changed. The run log says which import could not be loaded.
