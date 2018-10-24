# eSIT4SIP - Scenario translator
The main language of the scenarios written in the eSIT4SIP project is English. The scenarios presented by Lehrer-Online are written in German.  So we decided to provide at least an englisch title and abstract. The program 'translate_scenarios' translates user-defined fields into a user-defined language. It uses https://translate.yandex.net API to translate the content. Translation requests are made over HTTP Post with Typhoeus gem. The program will output a .json file with suffix 'previousFilename-translated'.

## Usage

### Ruby & Gems used

* ruby (>= 2.2.4)
* highline (>= 2.0.0.pre.develop.9)
* typhoeus (>= 1.3.0)

### Hardcode your settings in .rb file!

* Download this repository and open translate_scenarios.rb
* MAINPAGE_TRANSLATE_FIELDS: Define the .json fields you want to be translated and name their target field
* SUBPAGE_TRANSLATE_FIELDS: Do the same steps for subpages. This is optional since subpages are experimental.
* YANDEX_KEY: Add your Yandex Translator API key. (See: [Translate API Documentation]https://tech.yandex.com/translate/doc/dg/concepts/About-docpage/))

### How to run translate_scenarios

* Open shell and navigate to the project folder
* Type: ```ruby translate_scenarios.rb``` and press Enter
* You are asked to enter the source and target languages. (See [Supported languages]https://tech.yandex.com/translate/doc/dg/concepts/api-overview-docpage/)
* Choose a scenario .json file. Make sure the files are in the same directory as the translate_scenarios.rb

## Important
If you use the yandex translation service you have to generate your own API key. Furthermore you must comply with their license terms. For example you have to add the text "Powered by Yandex.Translate". This is not done by this program! In case of eSIT4SIP this is done by the 'xwiki_uploader'. See [Requirements for the use of translation results]https://tech.yandex.com/translate/doc/dg/concepts/design-requirements-docpage/) for more details.

## License
Copyright 2017 eSIT4SIP Project
Licensed under the EUPL, Version 1.2 only (the "Licence");
You may not use this work except in compliance with the Licence.
You may obtain a copy of the Licence at:

https://joinup.ec.europa.eu/software/page/eupl

Unless required by applicable law or agreed to in writing, software distributed under the Licence is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the Licence for the specific language governing permissions and limitations under the Licence.