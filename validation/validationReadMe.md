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

**Example: How to use the validator**

Validation of Common Impact Data Standard JSONLD should be performed with Apache Jena’s SHACL validation tool, and the SHACL files from the repository. If needed, instructions for locally installing Apache Jena’s SHACL tools (on a MacBook) are provided in Github’s CIDS/validation/ folder. 

With Jena installed, and with SHACL file `cids.shacl.ttl`, and JSONLD file `my-data.jsonld`, run the Terminal command from the folder where the files are located:

`shacl validate -s cids.shacl.ttl -d my-data.jsonld > report.ttl`

The validator will return a report file detailing whether any of the datatypes, relationships, or other restrictions defined by the data standard are incorrect. 

We don’t know yet if validation results are exactly the same validators in other languages (e.g. `pyshacl` for python environments). We recommend using Jena until we can confirm that results are consistent using other tools. 

**Interpreting validation results**

The ontology definitions in the SHACL files, and in particular the cardinality restrictions, are much stricter than is probably necessary for most SPO users to feel confident that their data is complete. For example: `hasDescription` can usually be optional for Indicators, not a strict requirement. It is a strict requirement for aligned software to *include* a text field for descriptions of Indicators in their schema, but not necessarily a requirement for SPOs to populate it. For this reason, some 'noisy' results like missing `hasDescription` values have had their violation severity level lowered from "Violation" to "Warning" or "Info" level in the SHACL files, and can likely be safely ignored. 

**For users prior to CIDS version 3.2**

Using SHACL files for validation is a significant (but we hope, welcome) change that provides more transparency and insight into the workings of the data standard. We are in the process of updating our Airtable Extension and Excel Add-on so that they consistently import/export files that pass validation. If you have an Airtable base or workbook running an older version of the Extension/Add-on, the main changes to align to CIDS version 3.2 are:

* Check that you are using `org:hasName` and not `cids:hasName` as the dataproperty for instance names on the `Theme`, `Outcome`, `Indicator`, and `IndicatorReport` classes.  
* Update `OrganizationProfile` to use the new `cids:Address` model for postal addresses.  
* Datatypes for `hasSize`, `hasTeamSize`, and `hasEDGSize` should be integers, but were imported/exported as strings.  
* Read and implement the new guidance on ISO 21972 included with the release notes for version 3.2.0: [unit\_of\_measure](https://docs.google.com/document/d/1uYTOpFYPfFz2eKiRdUWi9RxWWILsU5P7L_IrCLre2_Q/edit?tab=t.0).
