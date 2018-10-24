# eSIT4SIP - Tag mapper
The 'tag_mapper' analyzes scenarios and adds tags defined in the eSIT4SIP project. The program reads .json scenario files generated by 'scraper_mnstep' and 'scraper_lehreronline'. The program iterates over each scenario and uses string comparison to find matching tags. If there is a matching tag it is added to a pre-defined json field and then saved to file. The mapping files are written in .json and can be found in the subfolder 'mapper_json'. The resulting .json files are structured in a way the 'xwiki_uploader' can read and upload to eSIT4SIP-XWiki.

## Usage

### Ruby & Gems used

* ruby (>= 2.2.4)

### Optional settings

* Download this repository and open tag_mapper.rb
* Set your "Fields to be analyzed". See the examples in the program file.
* Adjust the mapper files in subdirectory 'mapper_json'

### Preparations

* Run 'scraper_mnstep' or 'scraper_lehreronline'
* Copy the output files to the directory where tag_mapper.rb is located.

### How to run tag_mapper

* Open shell and navigate to the project folder
* Type: ```ruby tag_mapper.rb``` and press Enter
* Choose the file you want to analyze.

## License
Copyright 2017 eSIT4SIP Project
Licensed under the EUPL, Version 1.2 only (the "Licence");
You may not use this work except in compliance with the Licence.
You may obtain a copy of the Licence at:

https://joinup.ec.europa.eu/software/page/eupl

Unless required by applicable law or agreed to in writing, software distributed under the Licence is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the Licence for the specific language governing permissions and limitations under the Licence.