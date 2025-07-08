# Why Are There So Many RDF Formats?

RDF is an abstract tool for describing graphs. Because it is abstract, it can be rendered in a number of different formats. RDF refers to the abstract framework, while each format has its own particular structure. Note that from the standpoint of RDF, each of these formats are equivalent to one another - if you express RDF in one format, you should be able to transform it to another format (or __serialization__) that can in turn be interpreted (or __parsed__) back into a common internal format. 

Because of this, RDF is becoming increasingly commonly used as a general data description format, regardless of whether the environment uses JSON, XML, Turtle (a specialized language), CSV (for  spreadsheets), YAML, or even HTML. 

Each format has its own advantages (and disadvantages):

* __RDF-XML.__ This is an XML variant of RDF, that also takes advantage of the RDF Schema language to describe specific data structures. Because XML was developed around the same time as RDF, RDF-XML was also used fairly heavily by OWL (the Web Ontology Language), which is a language for describing logical inferences. For this reason is it not uncommon to see rdf-xml files referred to as __OWL files__, even if they don't actually contain any OWL content.

* __Turtle.__ In 2007, the SPARQL language was first developed as a way of querying RDF. It turned out that its notation was considerably more condensed than using XML, and eventually, the __Terse RDF Language__ (__Turtle__) was standardized as a way of describing RDF, becoming a formal specification in 2013. If you are working with RDF on a regular basis, learning Turtle is probably a skill worth acquiring.

