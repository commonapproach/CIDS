# Common Impact Data Standard validation using SHACL

# CIDS Data Validation using SHACL

This document outlines the process for generating and using a SHACL file to validate data against the Common Impact Data Standard (CIDS) ontology.

The workflow consists of two main steps:
1.  **Generation**: A Tarql query (`generateShacl.sparql`) is run against a CSV file (`alignment3.csv`) to automatically generate SHACL shapes (`shacl.ttl`).
2.  **Validation**: A Python script (`validate_script.py`) uses the generated `shacl.ttl` file to validate a given CIDS RDF data file.

---

## 1. Generating SHACL Shapes (`shacl.ttl`)

The `shacl.ttl` file contains the set of rules and constraints used for validation. It is not created manually but is generated from a source **CSV file** (`CIDSandSFF.csv`) using the **Tarql** tool. The CSV file is derived from the `cids.ttl` and `sff.ttl` ontology files.

### How it Works

The file `generateShacl.sparql` is a special SPARQL query designed for Tarql. It contains mappings that convert the columns of a source CSV file (e.g., `CIDSandSFF.csv`) into RDF triples on the fly. It then uses a `CONSTRUCT` block to build SHACL shapes from this temporarily generated RDF data.

This approach allows you to define validation rules in a structured CSV and automatically translate them into a formal SHACL file.

### Prerequisites

The generation step requires **Tarql**. Tarql requires Java, which Homebrew will install automatically as a dependency if needed. For Mac OS:

```bash
brew install tarql
```

### How to Run (mac OS)

To generate the `shacl.ttl` file, open your terminal, navigate to the project directory, and run the tarql command. It takes the SPARQL query file and the source CSV data file as arguments. You can direct the output (>) to a new file.

```bash
tarql generateShacl.sparql alignment3.csv > shacl.ttl
```

This command will execute the mappings in the query file on `CIDSandSFF.csv` and save the resulting SHACL shapes into the shacl.ttl file.

## 2. Validating CIDS Data (validate_script.py)

The `validate_script.py` is used to check if a JSONLD file containing CIDS data (an "impact data capsule") conforms to the rules defined in `shacl.ttl`.

### Prerequisites

The script requires the pyshacl library. Install it using pip:

```bash
pip install pyshacl
```

### How to Run
The script takes the path to the RDF data graph file and the SHACL shapes file (shacl.ttl) as command-line arguments.

```bash
python validate_script.py <path_to_your_data.ttl> <path_to_shacl.ttl>
```

Example:
```bash
python validate_script.py my_cids_data.ttl shacl.ttl
```

### Output

If the data is valid: The script will print a conformation message to the console.

If the data is invalid: The script will print a detailed validation report identifying which data nodes violate which shapes and why.

## File Descriptions

* `generateShacl.sparql`: A Tarql query file containing mappings to convert a CSV file to RDF and a CONSTRUCT query to generate SHACL shapes from that data.
* `CIDSandSFF.csv`: a source CSV file that contains the definitions for the SHACL rules.
* `shacl.ttl`: The output file containing the SHACL shapes. This file is the "ruleset" for validation.
* `validate_script.py`: A Python script that uses the pyshacl library to validate an RDF data file against the `shacl.ttl` ruleset.