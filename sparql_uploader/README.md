# eSIT4SIP - SPARQL uploader
The 'sparql_uploader' is used to upload data from .json files to a SPARQL 1.0/1.1 endpoint. In case of eSIT4SIP, the slurped scenarios from the eSIT4SIP xWiki are uploaded to Apache Jena Fuseki (triple store). The program lets the user choose a .json file he wants to upload. Then a RDF graph is built. Afterwards the graph gets inserted by the sparql-client gem over HTTP. 

## Usage

### Fuseki preparations:

* A running triple store (sparql_uploader was tested with Apache Jena Fuseki 3.8.0) (See: [Fuseki](https://jena.apache.org/documentation/fuseki2/))
* Upload your ontology RDF files (optional). Fuseki offers a GUI for this purpose. 

### Ruby & Gems used

* ruby (>= 2.2.4)
* sparql-client (>= 3.0.0) (See its dependencies [here](https://github.com/ruby-rdf/sparql-client/))

### What data to upload?
The sparql_uploader uploads scenarios to a Apache Jena Fuseki instance (triple store). These are the scenarios we slurped with the xwiki_slurper. The slurper downloads all scenarios we wrote on our eSIT4SIP-XWiki. Its output also includes a articles.json file which is already structured in a way the sparql_uploader can read it. To get an impression of the .json structure, we provide you an example in articles-example.json. 

### Hardcode your settings in .rb file!

* Download this repository and open sparql_uploader.rb
* Let the SPARQL_ENDPOINT point to the update service of your dataset/endpoint
* Adjust the RDF vocabularies (See [Using ad-hoc RDF vocabularies](https://github.com/ruby-rdf/rdf))
* Keep UPLOAD_TO_FUSEKI = true if you want to upload to your triple store
* Read the annotations regarding the 'require' of the sparql client gem

### How to run sparql_uploader

* Open shell and navigate to the project folder
* Type: ```ruby sparql_uploader.rb```
* Choose the file you want to upload. For a test you can use articles-example.json

## License
Copyright 2017 eSIT4SIP Project
Licensed under the EUPL, Version 1.2 only (the "Licence");
You may not use this work except in compliance with the Licence.
You may obtain a copy of the Licence at:

https://joinup.ec.europa.eu/software/page/eupl

Unless required by applicable law or agreed to in writing, software distributed under the Licence is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the Licence for the specific language governing permissions and limitations under the Licence.