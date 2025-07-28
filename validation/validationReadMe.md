# Common Impact Data Standard data validation with SHACL files

SHACL (SHApes Constraint Language) is part of the W3C stack for RDF, and is very useful for validation of RDF files. They describe “shapes” (patterns in data types and connections) in RDF files. Please see also our short write up on “[what is SHACL](https://github.com/commonapproach/CIDS/blob/main/faq/what-is-shacl.md)” in our new FAQ for developers.  

**How SHACL validation works**

A SHACL file comprehensively contains all the rules for classes, datatypes, and relationships that are described in the Common Impact Data Standard definition (OWL) files, but in a format that is easier for computers to apply than directly reading OWL files. SHACL files are used to validate RDF files like the JSONLD files exported by aligned software. Our SHACL files are published in the Turtle (.ttl) RDF syntax. 

**What is available now**

Common Approach has published SHACL files for the Common Impact Data Standard and Social Finance Fund companion module. These are available now at  [https://github.com/commonapproach/CIDS/tree/main/validation](https://github.com/commonapproach/CIDS/tree/main/validation). 

There is a separate SHACL file for each namespace, or source ontology, of classes and properties used in the Common Impact Data Standard. The main one is the cids: namespace file (`cids.shacl.ttl`) which contains the core classes and properties for the Standard. Other ontology extensions and imported standards have their own files, e.g.:

* SFF companion module: `sff.shacl.ttl`  
* ISO 21972, for measurement: `i72.shacl.ttl`

**How to use the validator**

Validation of Common Impact Data Standard JSONLD should be performed with Apache Jena’s SHACL validation tool, and the SHACL files from the repository. If needed, instructions for locally installing Apache Jena’s SHACL tools (on a MacBook) are provided in Github’s CIDS/validation/ folder. 

With Jena installed, SHACL file `cids.shacl.ttl`, and JSONLD file `my-data.jsonld`, run the command

`shacl validate -s cids.shacl.ttl -d my-data.jsonld > report.ttl`

The validator will return a report file detailing whether any of the datatypes, relationships, or other restrictions defined by the data standard are incorrect. 



We don’t know yet if validation results are exactly the same validators in other languages (e.g. `pyshacl` for python). We recommend using Jena until we can confirm that results are consistent using other tools. 

To validate all core and imported classes and properties in a JSONLD file, validation tests must iteratively use each `shacl.ttl` file. In future we hope to develop a refined validation script that provides the convenience of a single consolidated file for validation.  

**Interpreting validation results**

The ontology definitions in the SHACL files, and in particular the cardinality restrictions, are much stricter than is probably necessary for most SPO users to feel confident that their data is complete. For example: `hasDescription` can usually be optional for Indicators, not a strict requirement. It is a strict requirement for aligned software to *include* a text field for descriptions of Indicators in their schema, but not necessarily a requirement for SPOs to populate it. 

The first version of this SHACL-based validation approach will almost certainly always “fail” JSONLD files for not meeting cardinality requirements and leaving required values empty. A top priority for us is to create more refined levels of violation severity in the SHACL files, so that users can distinguish ‘critical’, ‘warning’, and ‘info’ level issues with their impact data. 

**Ensuring your software can import and export JSONLD that passes validation**

This approach to validation is a significant (but we hope, welcome) change for those who previously used our Airtable Extension as the basis for validating JSONLD files. We are in the process of updating our Airtable Extension and Excel Add-on so that it imports/exports files that pass validation by the new SHACL files. The main changes to note are:

* Check that you are using `org:hasName` and not `cids:hasName` as the dataproperty for instance names on the `Theme`, `Outcome`, `Indicator`, and `IndicatorReport` classes.  
* Update `OrganizationProfile` to use the new `cids:Address` model for postal addresses.  
* Datatypes for `hasSize`, `hasTeamSize`, and `hasEDGSize` should be integers, but were imported/exported as strings.  
* Read and implement the new guidance on ISO 21972 included with the release notes for version 3.2.0: [unit\_of\_measure](https://docs.google.com/document/d/1uYTOpFYPfFz2eKiRdUWi9RxWWILsU5P7L_IrCLre2_Q/edit?tab=t.0).