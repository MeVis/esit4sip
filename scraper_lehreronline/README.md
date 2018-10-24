# eSIT4SIP - Lehrer-Online webscraper
The 'scraper_lehreronline' uses webscraping technologies to fetch teaching activities of 'Lehrer-Online'. Lehrer-Online describes itself as the leading editorial material and service portal for teachers of all types and levels of education. On www.lehrer-online.de teachers will find high-quality and pedagogically tested teaching material that they can use freely and legally in their lessons. Source: https://www.lehrer-online.de/ueber-uns/

The 'scraper_lehreronline' program opens https://www.lehrer-online.de and uses the search form to find the terms defined in scraper_lehreronline.rb (see KEYWORDS). Then it fetches the results/activities returned by the search. There it analyzes the content of each activity and will save it in appropriate fields in a .json file. The resulting .json files are structured in a way the 'xwiki_uploader' can read and upload the data to the eSIT4SIP-XWiki. Media elements such as e.g. jpg or text files are not downloaded.

## Usage

### Ruby & Gems used

* ruby (>= 2.2.4)
* mechanize (>= 2.7.5)
* nokogiri (>= 1.8.2)

### Hardcode your settings in .rb file!

* Download this repository and open scraper_lehreronline.rb
* Enter the KEYWORDS you want the scraper to search for
* Keep PARSE_SUBPAGES = false; Parsing subpages is experimental 
* Optionally modify the String class extension by your markup

### How to run scraper_lehreronline

* Open shell and navigate to the project folder
* Type: ```ruby scraper_lehreronline.rb``` and press Enter

## Important
This software only downloads activities (called scenarios here too) with a free-license. It explicitly ignores scenarios offered in their premium program. We guarantee that we maintain the license of the scenarios.

## License
Copyright 2017 eSIT4SIP Project
Licensed under the EUPL, Version 1.2 only (the "Licence");
You may not use this work except in compliance with the Licence.
You may obtain a copy of the Licence at:

https://joinup.ec.europa.eu/software/page/eupl

Unless required by applicable law or agreed to in writing, software distributed under the Licence is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the Licence for the specific language governing permissions and limitations under the Licence.