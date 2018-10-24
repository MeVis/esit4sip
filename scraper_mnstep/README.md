# eSIT4SIP - MnSTEP webscraper
The 'scraper_mnstep' uses webscraping technologies to fetch teaching activities of the 'MnSTEP Teaching Activity Collection'. "The [MnSTEP] activities reflect individual integration plans for applying newfound content knowledge and inquiry strategies directly in classroom curriculum and practice". Source: https://serc.carleton.edu/sp/mnstep/ 

The 'scraper_mnstep' program opens http://serc.carleton.edu/sp/mnstep/activities.html and uses the search form to find the terms defined in scraper_mnstep.rb (See KEYWORDS). Then it fetches the results/activities returned by the search. There it analyzes the content of each activity and will save it in appropriate fields in a .json file. The resulting .json files are structured in a way the 'xwiki_uploader' can read and upload the data to the eSIT4SIP-XWiki. Media elements such as e.g. jpg or text files are not downloaded.

## Usage

### Ruby & Gems used

* ruby (>= 2.2.4)
* mechanize (>= 2.7.5)
* nokogiri (>= 1.8.2)

### Hardcode your settings in .rb file!

* Download this repository and open scraper_mnstep.rb
* Enter the KEYWORDS you want the scraper to search for
* Optionally modify the String class extension by your markup

### How to run scraper_mnstep

* Open shell and navigate to the project folder
* Type: ```ruby scraper_mnstep.rb```

## License
Copyright 2017 eSIT4SIP Project
Licensed under the EUPL, Version 1.2 only (the "Licence");
You may not use this work except in compliance with the Licence.
You may obtain a copy of the Licence at:

https://joinup.ec.europa.eu/software/page/eupl

Unless required by applicable law or agreed to in writing, software distributed under the Licence is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the Licence for the specific language governing permissions and limitations under the Licence.