# What is SHACL?

## OWL Shows its Age
[OWL](what-is-owl.md) was introduced in 2001, making it one of the oldest artifacts of the Semantic Web. The first official version was ratified in 2004, with updates in 2007, and again in 2012. The fundamental principle on which it was built was that you could use inferencing to discover or surface relationships that weren't explicitly entered into the knowledge graph.

However, OWL inferencing can become very complex, producing far more information than was actually useful, and combinatorial constraints limited its efficacy for very large datasets (it has trouble scaling). Moreover, the model that OWL uses differs significantly from the way that other data modeling standards are built, and outside of the Semantic Web community, there was comparatively little adoption because of this discrepancy between the two underlying models.

Additionally, OWL was developed prior to the advent of SPARQL, and many of the generalized patterns that initially used triple generation for inferencing were increasingly being done better with SPARQL. This became especially true with the advent of SPARQL Update, released in 2013, which made it possible to write directly into the graph from within the graph. 

Finally, a number of key innovations since OWL was created, including RDF-Star and named graphs, had to be retrofitted into OWL, in ways that were becoming more cumbersome than beneficial.

## The Introduction of SHACL

In 2015, the W3C started a working group based upon a new Shape-based language originally called SHEX, with the working name eventually becoming __the SHApe Constraint Language__ (or __SHACL__).

The notion of a __shape__ is something that has evolved considerably from the early days of OWL classes. In essence, a shape can be thought of as a way of describing a data structure in terms of its constraints, independent of any specific inferential logic.

SHACL defines a number of different types of shapes, but the two most heavily used are NodeShapes (which are analogous to but more general than classses) and PropertyShapes (which are analogous to property definitions, but again, more generalized). 

## SHACL Roles

Shapes can be used to make properties and classes more contextual and serve several different purposes:

* __Validation.__ This basically tests a given node to determine whether it satisfied the conditions of a shape, and generates a report of the node is not conformant. This report generation capability is something that OWL by itself does not do, though there are ontologies which can support, to a certain degree, such generation.
* __Classification.__ As the flipside to validation, classification takes a given node and finds which shape(s) it corresponds to. This process of classification is especially useful when dealing with data structures that aren't clearly identified structurally, and as such this can be used for filtered processing of incoming data streams.
* __UI Generation.__ There is a very close overlap between schema design and UI form and display components, and increasingly SHACL is being used to facilitate that.
* __New Instance Generation.__ Often what gets passed to a process is a set of parameters that can be treated as a dataset. SHACL can be used in conjunction with SPARQL to identify and populate the structure of new entities without having to do so manually, significantly reducing the overall complexity of coding.
* __Structural Recursion.__ SPARQL is not recursive - it processes a linear dataset. However, SHACL can introduce recursive invocations that can better handle analysing and processing hierarchical data structures.
* __Mapping to DOM Structures.__ SHACL can also be used to generate programmatic DOM structures from RDF in external languages such as python or javascript.


