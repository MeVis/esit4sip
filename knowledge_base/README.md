# eSIT4SIP - Knowledge Base
The knowledge base has been developed in order to assist teachers to easily find ICT-enhanced learning scenarios that match their individual requirements. The eSIT4SIP knowledge base contains a large collection of state-of-the-art learning scenarios that have been developed and tested by school practitioners and that is constantly extended and updated. The eSIT4SIP web site offers an easy-to-use search interface that allows querying the knowledge base for suitable scenarios. The goal is to support teachers in setting up their learning designs and inspire them by presenting new ideas on what may be feasible using modern technology in the classroom. 

## Setup: The easy way

* Simply download the repository and open the index.html file in your browser
* The scenario data presented in the "search" area is requested from the eSIT4SIP triple store (Apache Fuseki server)
* The button "browse the knowledge base" links to the WebVOWL WebApp running on eSIT4SIP server,

In the next steps you will learn how to modify the files to load your (scenario) data and visualize your ontology. 

## Setup your own knowledge base

You can easily setup your own knowledge base and present your learning scenarios. You can choose between two sources your scenario data comes from:

* The static articles.json file in your the directory "data"
* The dynamic data request via SPARQL using a triple store (e.g. Apache Fuseki server)

### Scenario data from static articles.json file

Per default, the scenario data used on www.eSIT4SIP.eu is loaded dynamically via SPARQL request. To load scenario data from the static data/articles.json, open assets/js/filter_kb.js. Search for "get articles by static .json" and umcomment this area of code. Make sure you disable the area "get articles by sparql" to prevent data-request twice. We provide you a shortened example ouf articles.json to get an understanding of the used data structure. 
With this approach you will be not able to provide the functionality "Can id do this" which is described below. 

### Scenario data by dynamic SPARQL request

Per default, the scenario data used on www.eSIT4SIP.eu is loaded dynamically. We use SPAQRL language and a Apache Fuseki server which provides a SPARQL endpoint. We use a http-request to query the server and return scenario data.
These steps are necceassary:

* A running instance of Apache Fuseki server (See: [Fuseki](https://jena.apache.org/documentation/fuseki2/))
* Upload your ontology RDF files to the server. Fuseki offers a GUI for this purpose. 
* Upload your scenario data. For eSIT4SIP project we wrote the ruby program 'sparql_uploader'. 

Modify filter_kb.js

* Enter your SPARQL endpoint in constant "ENDPOINT"
* Modify the 'build_query' string to enter your SPARQL query
* Modify the 'build_articles' function to map the incoming data to the structure required by the filter system. To get an understanding of the structure you can have a look at data/articles.json. The 'build_articles' function rebuilds this structure.

### The 'data' directory

By inspecting the data/articles.json or the returned data from SPARQL request, you will notice that the data only contains metainformations about a scenario. For example: title, summary, translation information. But if the user clicks on a scenario on www.esitsip.eu the complete scenario text appears. This is done by ajax-loading a corresponding .html file. A scenario can be identified by its 'id'. By this, the .html file gets loaded from the 'data' folder. So for each scenario a .html file has to be present in the 'data' directory. Since a scenario can also have translations, there are files with a translation suffix e.g. en, de. As soon the user chooses a translation on www.esitsip.eu these files are loaded.
A scenario can also have embedded files and images. They are saved in the sub-directory 'attachments'. For each scenario another directory exists containing its files. 

The 'data' directory furthermore contains the articles.json and tags.json files. The purpose of articles.json is described above. On www.esitsip.eu the tags.json play an important role: By this the filter plugin knows how to build the seach facets on the left. It iterates over its groups and tags and appends bootstrap-dropdowns and checkboxes. 

We recommend you to use our 'xwiki_slurper' program which automatically downloads XWiki content and generates the proposed file structure.

### WebVOWL
www.esitsip.eu uses WebVOWL to let the user explore the knowledge base and ontology with an interactive visualization. "WebVOWL is a web application for the interactive visualization of ontologies. It implements the Visual Notation for OWL Ontologies (VOWL) by providing graphical depictions for elements of the Web Ontology Language (OWL) that are combined to a force-directed graph layout representing the ontology" (Source: [WebVOWL](http://vowl.visualdataweb.org/webvowl.html/)). You can run WebVOWL in two ways:
* Simply run the index.html in the 'webvowl' directory. By its configuration it will run the static 'ontology.json' file in the subdirectory 'data'. The .json file was created with the ["OWL2VOWL converter"](http://vowl.visualdataweb.org/webvowl.html). This program converts your ontology in a WebVOWL-readable json file. If you change your ontology you have to re-run the converter. If you want to rename the 'ontology.json' file you have to change the 'default_ontology' string in 'webvowl.app.js'.
* www.esitsip.eu uses WebVOWL in a dynamic way. We deployed it as Web Application Archive (WAR) on a Tomcat server. As it consists of OWL2VOWL and WebVOWL you can add your Fuseki IRI. The WAR then will automatically convert and visualize the ontology. Example: http://www.esit4sip.eu/webvowl/#iri=http://www.esit4sip.eu/fuseki/esit4sip/get

## Technical overview

The eSIT4SIP knowledge base is realized as a website using web technologies (HTML, CSS, JavaScript). Its uses the following third party technologies:

* [Filter.js](https://github.com/jiren/filter.js): Filter.js is client-side JSON objects filter which can render html elements. Multiple filter criteria can be specified and used in conjunction with each other.
* [Bootstrap 3](https://getbootstrap.com/docs/3.3/): A HTML, CSS, and JS framework for developing responsive, mobile first projects on the web.
* [WebVOWL](http://vowl.visualdataweb.org/webvowl.html): A web application for the interactive visualization of ontologies.
* [URI.js and jquery.URI.js.](http://medialize.github.io/URI.js/): URI.js is a javascript library for working with URLs. 
* [table.js](https://github.com/seandolinar/Quick-jQuery-Table): A simple table builder.
* [WebUI-Popover](https://github.com/sandywalker/webui-popover): A lightWeight popover plugin with jquery, enchance the popover plugin of bootstrap.
* [clipboard.js](https://clipboardjs.com/): A library to copy text to clipboard

## License
Copyright 2017 eSIT4SIP Project
Licensed under the EUPL, Version 1.2 only (the "Licence");
You may not use this work except in compliance with the Licence.
You may obtain a copy of the Licence at:

https://joinup.ec.europa.eu/software/page/eupl

Unless required by applicable law or agreed to in writing, software distributed under the Licence is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the Licence for the specific language governing permissions and limitations under the Licence.