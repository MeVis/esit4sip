# eSIT4SIP - Ontology
The eSIT4SIP approach is based on a learning and infrastructure ontology. The ontology serves as a standardized vocabulary to tag learning scenarios and design patterns in the eSIT4SIP knowledge base. Furthermore, it serves as the semantic backbone to express relations between scenarios and to link them to learning and infrastructure concepts.

You may explore the knowledge base and ontology with an interactive visualization that can be accessed here: http://www.esit4sip.eu/webvowl/#iri=http://www.esit4sip.eu/fuseki/esit4sip/get 

## Description of files:

* learning.rdf: Ontology containing classes related to learning (Scenarios, Baumgartner, etc.)
* learning-instances.rdf: Example instances for learning ontology
* infrastructure.rdf: Some classes related to infrastructure (should be replaced by latest version of Miltos' work)
* infrastructure-instances.rdf: Example instances for infrastructure ontology. Imports all other ontologies => complete ontology with examples for testing queries
	
## Current state of development:

27.7.2018:
- Created all classes required for the data from the scenarios scraped from the web
- Example query for finding devices offering the same affordance as a given device
- Basic datatype properties for scenario defined (based on scraped data)

TODO:
- Check object properties in learning ontology
- Define use case(s) to be realized in web frontend using the ontology
- Develop example queries for retrieving instances from learning ontology based on use cases