# What is SPARQL?

If RDF is the data model for a knowledge graph, then __SPARQL__ (SPARQL Protocol and RDF Query Language) is its query language. For a developer, the simplest analogy is that SPARQL is to a graph database (triple store) what SQL is to a relational database. It is the W3C-standardized language for retrieving and manipulating data stored in the Resource Description Framework (RDF) format.

SPARQL was first developed in 2007 to provide a uniform way to query the rapidly growing web of linked data. Before SPARQL, every triple store had its own proprietary query language, creating significant vendor lock-in. SPARQL provided a standard that abstracted away the underlying storage, allowing developers to write queries that could run on any compliant RDF database. Its graph pattern notation was so efficient that it heavily influenced the syntax of Turtle, a popular RDF format.

At its core, a SPARQL query consists of graph patterns that look like RDF triples, but with variables. The `WHERE` clause contains these patterns, which describe the shape of the data you want to find. For example, to find the names of every outcome in a dataset, you might write a pattern like: 

`?outcome rdf:type cids:Outcome ; org:hasName ?name .` 

The query processor matches this pattern against the graph and returns the values bound to the `?outcome` and `?name` variables.

While the most common query form is `SELECT`, which returns a table of results like SQL, SPARQL is more versatile:

* `CONSTRUCT` returns a new RDF graph based on your query results, allowing you to transform and export subsets of data.

* `ASK` returns a simple boolean `true` or `false`, useful for validation or checking for the existence of a specific pattern.

* `DESCRIBE` returns a concise RDF graph describing a specific resource, with the exact scope often left to the implementation.

Initially a read-only language, SPARQL was extended in 2013 with SPARQL Update, which introduced data manipulation capabilities like `INSERT` and `DELETE`. This transformed SPARQL into a complete data management language, enabling applications to write back to the graph using the same pattern-based syntax used for querying. For many use cases, writing targeted `SPARQL UPDATE` queries became a more direct and performant alternative to performing complex OWL inferencing to generate new triples.