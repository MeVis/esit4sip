# esit4sip - XWiki slurper
The 'xwiki_slurper' is used to download articles from from a xWiki environment. In case of eSIT4SIP, the program downloads scenarios from eSIT4SIP xWiki. The scenarios will be collected in a json file and saved as HTML. You can use the output to upload the scenarios to fuseki (triple store) via sparql_uploader. The attachments of a scenario are downloaded too. Furthermore we extract the navigation tags (see NAVIGATION_PAGE) to build search facets for www.esit4sip.eu The navigation tags are saved in a json file (default: tags.json) 

## Usage

### XWiki preparations:

* A running XWiki (xwiki_slurper was tested with XWiki Enterprise 7.4)
* A multilingual XWiki configuration (See: [XWIKI Internationalization](https://www.xwiki.org/xwiki/bin/view/Documentation/UserGuide/Features/I18N))
* A XWiki account with sufficient rights (CRUD) (See: [XWIKI Access Rights](https://www.xwiki.org/xwiki/bin/view/Documentation/AdminGuide/Access%20Rights/))
* A Xwiki father-space that has some children (See explanation below and [Content Organization](https://www.xwiki.org/xwiki/bin/view/Documentation/UserGuide/Features/ContentOrganization/))

The father space:
We use the concept of nested pages in XWiki when we write or upload scenarios. The XWiki documentation says: "You can create a hierarchy of pages, by creating pages inside other pages" [Link](https://www.xwiki.org/xwiki/bin/view/Documentation/UserGuide/Features/ContentOrganization/). You can also speak of a 'father space' and its 'children'. You can freely choose the name of the father space and write some child-articles (Note: if you are using the "xwiki_uploader" you have to follow the rules described there). The idea of the father space is an easier handling of the nested pages. This is important for us, because we will get a list of all children inside a father space by using the xWiki-API. 

Your content organization maybe will look like: 
* MyArticles (father)
* MyArticles.Atoms and Molecules (child)
* MyArticles.How Clouds are made (child)
...

### Ruby & Gems used

* ruby (>= 2.2.4)
* mechanize (>= 2.7.5)
* nokogiri (>= 1.8.2)
* typhoeus (>= 1.3.0)

### Hardcode your settings in .rb file!

* Download this repository and open xwiki_slurper.rb
* Set username and password
* Set the BASE_URL which points to your XWiki home
* Enter the father SPACES you want to download (see explanation above)
* Modify the constants like output directories or filenames (optional)

### How to run xwiki_slurper

* Open shell and navigate to the project folder
* Type: ```ruby xwiki_slurper.rb```

## License
Copyright 2017 eSIT4SIP Project
Licensed under the EUPL, Version 1.2 only (the "Licence");
You may not use this work except in compliance with the Licence.
You may obtain a copy of the Licence at:

https://joinup.ec.europa.eu/software/page/eupl

Unless required by applicable law or agreed to in writing, software distributed under the Licence is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the Licence for the specific language governing permissions and limitations under the Licence.