# Common Impact Data Standard data validation with SHACL files

SHACL (SHApes Constraint Language) is part of the W3C stack for RDF, and is very useful for validation of RDF files. They describe “shapes” (patterns in data types and connections) in RDF files. Please see also our short write up on “[what is SHACL](https://github.com/commonapproach/CIDS/blob/main/faq/what-is-shacl.md)” in our FAQ for developers.  

**How SHACL validation works**

A SHACL file comprehensively contains all the rules for classes, datatypes, and relationships that are described in the Common Impact Data Standard definition (OWL) files, but in a format that is easier for computers to apply than directly reading OWL files. SHACL files are used to validate RDF files like the JSONLD files exported by aligned software. Our SHACL files are published in the Turtle (.ttl) RDF syntax. 

**What is available now**

Common Approach has published SHACL files for the Common Impact Data Standard and Social Finance Fund companion module. These are available now at [https://ontology.commonapproach.org/](https://ontology.commonapproach.org/). 

There are different SHACL files for different levels of alignement with the Common Impact Data Standard. 

* The Basic Tier SHACL file (`cids.basictier.shacl.ttl`) only includes the Organization, Theme, Outcome, Indicator, and IndicatorReport classes. The Essential Tier adds additional classes and properties, as does Full Tier.
* the SFF Companion Module SHACL file (`sff.shacl.ttl`) contains everything from Basic Tier, as well as additional classes and properties required for participants reporting in the Social Finance Fund. 
* Other standards have their own files, e.g. ISO 21972, for measurement: `i72.shacl.ttl`. These may be used in addition to the CIDS and SFF files, if needed, but are not required for most cases. 

**Simple validation of JSON-LD files - Apache Jena**

Common Impact Data Standard JSON-LD files, or "Impact Data Capsules", can be validated against the SHACL files with Apache Jena’s `shacl validate` tool. 
With Jena installed, and with SHACL file `cids.shacl.ttl`, and JSONLD file `my-data.jsonld`, run the Terminal command from the folder where the files are located:

`shacl validate -s cids.shacl.ttl -d my-data.jsonld > report.ttl`

The validator will return a violations report file (in Turtle syntax) detailing whether any of the datatypes, relationships, or other restrictions defined by SHACL file are incorrect. 

**More efficient validation of JSON-LD files - with summarization script to aid interpretation of results**

Violation reports can potentially be quite long, and troubleshooting the causes of violations can be tedious. Common Approach has developed and shared a bash/zsh script that validates Impact Data Capsule files, and then calls a python script to summarize the violations report files. The summary report groups violations by violation type and by nodetype, and extracts the relevant value in violation from the source file, to make troubleshooting easier. The script (CIDS-validate.sh) and its documentation for use are available in [validation/shacl-validation]. 

**Interpreting common violation report results**

The ontology definitions in the SHACL files, and in particular the cardinality restrictions, are much stricter than is probably necessary for most SPO users to feel confident that their data is complete. For example: `hasDescription` can usually be optional for Indicators, not a strict requirement. It is a strict requirement for aligned software to *include* a text field for descriptions of Indicators in their schema, but not necessarily a requirement for SPOs to populate it. For this reason, some 'noisy' results like missing `hasDescription` values have had their violation severity level lowered from "Violation" to "Warning" or "Info" level in the SHACL files, and can likely be safely ignored. 

Impact Data Capsules that use the hasCode property to refer to items in various code lists or taxonomies may produce several ClassConstraint violations if the code list items are not included in the graph to be validated. These violations can be ignored, if the user is confident that the linked nodes are of the correct type, or, the [CIDS-validate.sh](shacl-validation) validation script provided by Common Approach includes the option of merging the available code lists from the [code list server](https://codelist.commonapproach.org) with the file to be validated, so that these errors are resolved. For more information see the README.md file for the validation script. 
