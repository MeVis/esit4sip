# esit4sip - XWiki uploader
The 'xwiki_uploader' is used to parse .json files and upload their data to a XWiki environment. In case of eSIT4SIP, webscraped scenarios are uploaded to the eSIT4SIP XWiki. The program uses HTTP-requests and the XWiki-API to upload scenario-pages.

## Usage

### XWiki preparations:

* A running XWiki (xwiki_uploader was tested with XWiki Enterprise 7.4)
* A multilingual XWiki configuration (See: [XWIKI Internationalization](https://www.xwiki.org/xwiki/bin/view/Documentation/UserGuide/Features/I18N))
* A XWiki account with sufficient rights (CRUD) (See: [XWIKI Access Rights](https://www.xwiki.org/xwiki/bin/view/Documentation/AdminGuide/Access%20Rights/))
* A wiki-space that serves as a father for the incoming scenario-pages. (See explanation below and [Content Organization](https://www.xwiki.org/xwiki/bin/view/Documentation/UserGuide/Features/ContentOrganization/))

The father space:
We use the concept of nested pages in XWiki when we upload scenarios. Before we use the uploader, we generate a father space in XWiki (per hand). The idea of the father space is an easier handling of the nested pages. For example, you can easily delete (all) subpages by deleting the father space. 
When it comes to the name of the father space you have follow some rules. Let's have an example: The space can be named 'AsMnSTEP', where the prefix 'As' is an abbreviation for 'AutomatedScenarios' and 'MnStep' is the source, where the scenario originally comes from. You can freely choose the 'As' space prefix (see below) while you can not choose the latter. 'MnStep' comes from the scenario .json file. 

Your content organization maybe will look like: 
* AsMnSTEP (father)
* AsMnSTEP.Atoms and Molecules (child)
* AsMnSTEP.How Clouds are made (child)
...

### .json file preparations
The xwiki_uploader parses .json files which are following a strict architecture. We provide you two example files where you can look up this architecture.
The .json files have to be in the same directory as the xwiki_uploader.


### Ruby & Gems used

* ruby (>= 2.2.4)
* highline (>= 2.0.0.pre.develop.9)
* typhoeus (>= 1.3.0)

### Hardcode your settings in .rb file!

* Download this repository and open xwiki_uploader.rb
* Windows user: you can colorize the log by setting COLORIZE_LOG = true (optional)
* Set username and password (required)
* Set the SPACE_URL; Example "https://wiki.yourdomain.eu/rest/wikis/xwiki/spaces/" (required)
* Set the SPACE_PREFIX if you want to add a prefix to your pages (optional)
* Update ASK_TO_OVERWRITE and OVERWRITE if you don't want to get overwrite warnings (optional)

### How to run xwiki_uploader

* Open shell and navigate to the project folder
* Type: ```ruby xwiki_uploader.rb```
* You will be asked to select the files you want to upload. The files have to be in the same directory.

## License
Copyright 2017 eSIT4SIP Project
Licensed under the EUPL, Version 1.2 only (the "Licence");
You may not use this work except in compliance with the Licence.
You may obtain a copy of the Licence at:

https://joinup.ec.europa.eu/software/page/eupl

Unless required by applicable law or agreed to in writing, software distributed under the Licence is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the Licence for the specific language governing permissions and limitations under the Licence.