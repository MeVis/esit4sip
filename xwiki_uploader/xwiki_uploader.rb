# ---- Program info ----
# The 'xwiki_uploader' is used to upload data from .json files to a xWiki environment.
# In case of eSIT4SIP, webscraped scenarios are uploaded to the eSIT4SIP xWiki.
# The program uses HTTP-requests and the xWiki-API to upload scenario-pages.

# For a general understanding of the xWiki API see:
# https://www.xwiki.org/xwiki/bin/view/Documentation/UserGuide/Features/XWikiRESTfulAPI
# For a general understanding of the xWiki content architecture see:
# https://www.xwiki.org/xwiki/bin/view/Documentation/UserGuide/Features/ContentOrganization/

# ---- Developers ----
# Alexander Gantikow
# Media and education management
# University of Education Weingarten
# Member of eSIT4SIP Project

# ---- Copyright ----
# Copyright 2017 eSIT4SIP Project
# Licensed under the EUPL, Version 1.2 only (the "Licence");
# You may not use this work except in compliance with the Licence.
# You may obtain a copy of the Licence at:

# https://joinup.ec.europa.eu/software/page/eupl

# Unless required by applicable law or agreed to in writing, 
# software distributed under the Licence is
# distributed on an "AS IS" basis, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied.
# See the Licence for the specific language governing
# permissions and limitations under the Licence.

# ---- Todos ----
# Let user retry an upload if an http-request fails
# Output a summary of success and errors at the end

require 'cgi'
require 'date'
require 'find'
require 'json'
require 'logger'
require 'optparse'

require 'highline/import'
require 'typhoeus'

# Log colorizing (windows user only)
# To facilitate the perception of errors we added color to the log
# Set COLORIZE_LOG to true if your are windows user
# Details: https://github.com/fazibear/colorize
COLORIZE_LOG = false
require 'colorize' if COLORIZE_LOG

# Login
# For each upload you have to provide a login
# Make sure your account has the required rights
USERNAME = "yourUsername"
PASSWORD = "yourPassword"

# Rest-URL to xWiki pages
# xWiki provides you a list of all spaces (pages) in the XML format
# We will supplement this URL later to upload the scenarios 
SPACE_URL = "https://wiki.yourdomain.com/rest/wikis/xwiki/spaces/"

# Space prefix:
# Each scenario will be uploaded as a child of a father space.
# We have to define the father by using the space prefix and the source.
# Space prefix: The default prefix-value 'As' is an abbreviation 'AutomatedScenarios'
# Source: The source defines where a scenario comes from e.g. MnSTEP or LehrerOnline
# Result: The father space will be e.g. 'AsLehrerOnline'
# The full space name is build in function 'build_url'.
# Details: xwiki.org/xwiki/bin/view/Documentation/UserGuide/Features/ContentOrganization/
SPACE_PREFIX = "As"

# If any page or translation exists, you will be asked to overwrite it per default.
# In times of big data this security step can be annoying.
# By setting ASK_TO_OVERWRITE to false, you will not be asked to overwrite.
# By setting OVERWRITE to true, you will overwrite any existing page.
# Note: OVERWRITE will only become active if ASK_TO_OVERWRITE is set false.
ASK_TO_OVERWRITE = true
OVERWRITE = false

# ---- Translations ----
# This program was built to upload content in different languages.
# To provide headlines in the correct language, 'translations' hash was made.
translations = {
	"summary"=> { "en" => "Summary", "de" => "Zusammenfassung" },
	"author" => { "en" => "Author: ", "de" => "Autor: " },
	"source" => { "en" => "Source: ", "de" => "Quelle: " },
	"categories" => { "en" => "Categories", "de" => "Kategorien" },
	"subject" => { "en" => "Subject: ", "de" => "Fach: " },
	"resource_type" => { "en" => "Resource type: ", "de" => "Unterrichtsmaterialien: " },
	"grade_level"=> { "en" => "Grade level: ", "de" => "Klassenstufe: " },
	"learning_goals" => { "en" => "Learning goals and competencies", "de" => "Lernziele und Kompetenzen" },
	"description" => { "en" => "Lesson description and teaching materials", "de" => "Beschreibung der Unterrichtseinheit und benötigtes Lehr-/Lernmaterial" },
	"didactic_comment" => { "en" => "Comment on pedagogy", "de" => "Didaktischer Kommentar" },
	"license" => { "en" => "License", "de" => "Lizenz" },
	"metadata" => { "en" => "Metadata ", "de" => "Metainformationen " },
	"title" => { "en" => "Title: ", "de" => "Titel: " },
	"authors" => { "en" => "Authors: ", "de" => "Autoren: " },
	"lesson_objectives" => { "en" => "Learning objectives: ", "de" => "Lernziele: " },
	"#grade_level" => { "en" => "Authors: ", "de" => "Autoren: " },
	"age" => { "en" => "Age: ", "de" => "Alter: " },
	"#subject" => { "en" => "Age: ", "de" => "Alter: " },
	"prerequisites" => { "en" => "Prerequisites: ", "de" => "Voraussetzungen: " },
	"difficulty_level" => { "en" => "Difficulty level: ", "de" => "Schwierigkeitsgrad: " },
	"duration" => { "en" => "Duration: ", "de" => "Dauer: " },
	"learning_environment" => { "en" => "Learning environment: ", "de" => "Lernumgebung: " },
	"teaching_approach" => { "en" => "Teaching approach: ", "de" => "Lehransatz: " }
}

# Logger settings
# Here the structure of the logger output is set
# For windows log-colors are added. See cons. COLORIZE_LOG
$log = Logger.new(STDOUT)
if COLORIZE_LOG 
	$log.formatter = proc { |type, date, prog, msg| 
		type = type.colorize( :background => :yellow) if type == "WARN"
		type = type.colorize( :background => :red) if type == "ERROR"
		type = type.colorize( :background => :red) if type == "FATAL"
		"#{type} --: #{msg}\n" 
	}
else
	$log.formatter = proc { |type, date, prog, msg| "#{type} --: #{msg}\n" }
end

# OptionParser: used for user inputs
$options = {}
OptionParser.new do |opt|
	opt.on('-o', '--overwrite_page') { |o| $options[:overwrite_page] = "y" }
	opt.on('-c', '--continue') { |o| $options[:continue] = "y" }
end.parse!

# Function by W. Mueller, Univ. of Education Weingarten
def self.get_parameter_from_option_or_ask(option_value, msg, default_value=nil, echo=true)
	return option_value unless option_value == nil
	say msg
	ask('> ') { |q| q.default = default_value; q.echo = echo }
end

# Function by W. Mueller, Univ. of Education Weingarten
def self.select_choice(menue)
	choose do |menu|
		menu.index = :number
		menu.index_suffix = ") "
		menu.prompt = "Select choice: "
		menue.each_with_index do |ch,i|
			menu.choice ch do
			  return i+1
			end
	  	end
	end
end

# Adding methods to string-class for method chaining
# These methods add xWiki-markup to a given string 
class String

	def italic
		return "//#{self}//"
	end

	def bold
		return "**#{self}**"
	end

	def underline
		return "__#{self}__"
	end

	def fontsize(size)
		return "(\% style='font-size: #{size}px;' %)#{self}(\%\%)"
	end

	def not_empty?
		!self.empty?
	end

	def newline(number)
		return self + "\n" * number
	end

	def to_title(type, newline_before, newline_after) 
		# Function to build title1, title2, title3... in xWiki markup
		# Returns: = title1 =, == title2 ==, === title3 === and so on
		content = ""
		content +="\n" * newline_before
		content += "=" * type + " " + self + " " + "=" * type 
		content +="\n" * newline_after
		return content
	end	

end

def list_files
	# This function lists all .json files in the same directory of this ruby program
	# It gets one or more filenames from the user input and returns an array of filenames to be uploaded
	files = Dir.glob("*.json")
	if files.empty? 
		$log.error("No json files found in current directory. Add files and restart program.")
		exit
	end

	# List file names
	puts "\nFound #{files.length} file(s) for uploading to XWiki."
	files.each_with_index { |file, i| puts i.to_s+ ": " + file }

	# User must choose files with only numbers and ,
	puts "Use numbers to choose files. Multiple files can be seperated by ',' " 
	chosen = gets.chomp
	loop do 
	  break if chosen =~ /^-?[0-9,]+$/
	  puts "Invalid input. Use numbers to choose files. Seperate with ','."
	  chosen = gets.chomp
	end 

	# Return choosen filenames as array
	file_names = Array.new()
	chosen = chosen.split(/\s*,\s*/)
	chosen = chosen.uniq
	chosen.each do |num|
		file_names << files[num.to_i] if num.to_i <= files.length
	end
	return file_names
end

def parse_json(filename)
	# This function pareses .json files by a given filename
	# Note: The file has to be in the same directory as this ruby program
	# Returns json data and success info (bool)
	begin
		file = File.read(filename, :encoding => 'UTF-8')
		data = JSON.parse(file)
		$log.info("Success: Parsing '#{filename}' was sucessful\n")
		success = true
	rescue JSON::ParserError
		$log.fatal("Could not parse #{filename}")
		success = false
		print "Continue in:"
		7.downto(0) do |i|
			print " #{i}"
			sleep 1
		end
		puts
	end
	return data, success
end

def build_url(prefix, space_url, source, title)
	# This function returns the URL where a scenario page should be uploaded
	# Param source: string, name of the provider where scenario was webscraped, e.g. "MnSTEP"
	# Param title: string, the title of the scenario (containg special characters)

	# First, this function builds the space_name e.g. "AsLehrerOnline"
	# Where 'As' is the default prefix and 'LehrerOnline' an example of a scenario-source found in json file
	# In a second step the scenario-url is built

	space_name = prefix + source	
	uri_title = build_uri_title(title)
	url = "#{space_url}#{space_name}/spaces/#{uri_title}/pages/WebHome"
	return url
end

def build_uri_title(title)
	# Build URI conform title
	# For uploading to xWiki we have to make sure that our URL does not contain special characters
	# Because the URL will contain the scenario title, we have to remove all special characters from it
	title = title.gsub('ä','ae').gsub('ö','oe').gsub('ü','ue')
	title = title.gsub('Ä','Ae').gsub('Ö','Oe').gsub('Ü','Ue')
	title = title.gsub('ß','ss')
	title = title.gsub(/[^0-9A-Za-z ]/, '').squeeze(" ")
	title = CGI.escape(title)
	return title
end

def build_short_title(title)
	# For logging purposes we build a short title
	title.length >= 40 ? (short_title = "#{title[0..40]}...") : (short_title = title)
end

def title_warning(title)
	# This function was introduced as a security step, to make sure the scenario has got a title
	if title.empty?
		puts
		$log.fatal("Couldn't find english title in scenario. This is required for an upload! Did you forget to translate the scenario into english?")
		$log.fatal("Exceptional exit!")
		exit
	end
end

def build_content_lehreronline(scenario, trans, lang)
	# This function returns the content of a LehrerOnline scenario as string.
	# We get the content of a sceanrio field, add xWiki-markup and append it to the string
	# Praram scenario: json object of a specific scenario
	# Param trans: hash array, abbrevation for 'translation', defined at program start
	# Param lang: string, abbrevation for 'language', used to access translations in hash array

	content = ""

	# ---- Title ----
	title = content_by_key(scenario, "title_de")
	title_warning(title)
	content += title.to_title(1,0,1)

	# ---- Summary ----
	text = content_by_key(scenario, "summary_de")
	content += text.italic if text.not_empty?

	# ---- Description & teaching materials ----
	head = trans["description"][lang].to_title(2, 1, 1)
	text = content_by_key(scenario, "description")
	text += content_by_key(scenario, "short_info")
	content += head + text if text.not_empty?

	# ---- Lesson procedure ----
	head = "Unterrichtsablauf".to_title(2, 1, 1)
	text = content_by_key(scenario, "unitplan")
	content += head + text if text.not_empty?

	# ---- Didactic comment ----
	head = trans["didactic_comment"][lang].to_title(2, 1, 1)
	text = content_by_key(scenario, "didactic")
	content += head + text if text.not_empty?

	# ---- Material ----
	head = "Lehr-/Lernmaterial".to_title(2, 1, 1)
	text = content_by_key(scenario, "material")
	content += head + text if text.not_empty?
			
	# ---- Extra information ----
	head = "Zusatzinformationen".to_title(2, 1, 1)
	text = content_by_key(scenario, "additional_info")
	content += head + text if text.not_empty?


	# ---- Learning goals and competencies ----
	head = trans["learning_goals"][lang].to_title(2, 2, 1)
	text = content_by_key(scenario, "competencies")
	content += head + text if text.not_empty?	

	# ---- License ----
	head = trans["license"][lang].to_title(2, 1, 1)
	text = content_by_key(scenario, "license")
	content += head + text if text.not_empty?

	# ---- Collect metadata ----

	# ---- Url ----
	url = content_by_key(scenario, "url")
	url = "[[Link>>url:#{url}]]" if url.not_empty?
	
	# ---- Categories ----
	subject = content_by_key(scenario, "subject").join(', ')
	resource_type = content_by_key(scenario, "learningtype").join(', ')
	grade_level = content_by_key(scenario, "grade_level").join(', ')
	spatial_settings = ""

	# ---- Add metadata ----
	content += "\n----"
	content += trans["metadata"][lang].to_title(2, 1, 2)
	content += trans["title"][lang].bold + title.newline(2)
	content += trans["source"][lang].bold + url.newline(2)
	content += trans["authors"][lang].bold + content_by_key(scenario, "author").newline(2)
	content += trans["lesson_objectives"][lang].bold.newline(2)
	content += trans["grade_level"][lang].bold + grade_level.newline(2)
	content += trans["age"][lang].bold.newline(2)
	content += trans["subject"][lang].bold + subject.newline(2)
	content += trans["prerequisites"][lang].bold.newline(2)
	content += trans["difficulty_level"][lang].bold.newline(2)
	content += trans["duration"][lang].bold.newline(2)
	content += trans["learning_environment"][lang].bold + spatial_settings.newline(2)
	content += trans["teaching_approach"][lang].bold.newline(2)

	# Add hidden ID
	id = content_by_key(scenario, "id")
	content += "{{html clean=\"false\"}}<span id=\"hidden-id\" style=\"display: none;\">#{id}</span>{{/html}}"

	return content
end

def build_content_mnstep(scenario, trans, lang)
	# This function returns the content of a MnSTEP scenario as string.
	# We get the content of a sceanrio field, add xWiki-markup and append it to the string
	# Praram scenario: json object of a specific scenario
	# Param trans: hash array, abbrevation for 'translation', defined at program start
	# Param lang: string, abbrevation for 'language', used to access translations in hash array

	content = ""

	# ---- Title ----	
	title = content_by_key(scenario, "title")
	title_warning(title)
	content += title.to_title(1,0,1)

	# ---- Summary ----
	text = content_by_key(scenario, "summary")
	content += text.italic if text.not_empty?

	# ---- Description & teaching materials ----
	head = trans["description"][lang].to_title(2, 1, 1)
	text += content_by_key(scenario, "description_and_teaching_materials")
	content += head + text if text.not_empty?
		
	# ---- Context for use ----
	head = "Context for Use".to_title(2, 1, 1)
	text = content_by_key(scenario, "context_for_use")
	content += head + text if text.not_empty?

	# ---- Teaching notes & tips ----	
	head = "Teaching Notes and Tips".to_title(2, 1, 1)
	text = content_by_key(scenario, "teaching_notes_and_tips")
	content += head + text if text.not_empty?	

	# ---- Assessment ----	
	head = "Assessment".to_title(2, 1, 1)
	text = content_by_key(scenario, "assessment")
	content += head + text if text.not_empty?	

	# ---- References and ressources ----	
	head = "References & Resources".to_title(2, 1, 1)
	text = content_by_key(scenario, "references_and_resources")
	content += head + text if text.not_empty?

	# ---- Learning goals and competencies ----
	head = trans["learning_goals"][lang].to_title(2, 2, 1)
	text = content_by_key(scenario, "learning_goals")
	content += head + text if text.not_empty?	

	# ---- License ----
	head = trans["license"][lang].to_title(2, 1, 1)
	text = content_by_key(scenario, "license")
	content += head + text if text.not_empty?

	# ---- Collect metadata ----
	url = content_by_key(scenario, "url")
	url = "[[Link>>url:#{url}]]" if url.not_empty?
	subject = content_by_key(scenario, "subject")
	grade_level = content_by_key(scenario, "grade_level")
	spatial_settings = content_by_key(scenario, "spatial_settings")

	# ---- Add metadata ----
	content += "\n----"
	content += trans["metadata"][lang].to_title(2, 1, 2)
	content += trans["title"][lang].bold + title.newline(2)
	content += trans["source"][lang].bold + url.newline(2)
	content += trans["authors"][lang].bold + content_by_key(scenario, "author").newline(2)
	content += trans["lesson_objectives"][lang].bold.newline(2)
	content += trans["grade_level"][lang].bold + grade_level.newline(2)
	content += trans["age"][lang].bold.newline(2)
	content += trans["subject"][lang].bold + subject.newline(2)
	content += trans["prerequisites"][lang].bold.newline(2)
	content += trans["difficulty_level"][lang].bold.newline(2)
	content += trans["duration"][lang].bold.newline(2)
	content += trans["learning_environment"][lang].bold + spatial_settings.newline(2)
	content += trans["teaching_approach"][lang].bold.newline(2)

	return content
end

def build_abstract_lehreronline(scenario)
	# LehrerOnlie scenarios are written in german. We decided to provide at least an english abstract
	# In this function we build the english abstract for LehrerOnline scenarios

	content = ""

	# ---- Title ----
	title = content_by_key(scenario, "title")
	content += title.to_title(1,0,2)
	
	# ---- Abstract ----
	abstract = content_by_key(scenario, "summary")
	if abstract.empty? == false
		content += abstract.italic
		content += "\n \nThis article is currently only available in german. See the original version {{html clean=\"false\"}}<span id=\"original_switch\" class=\"de\">here</span>{{/html}}."
		content += "\nThe above abstract was translated by [[Yandex Translate>>url:http://translate.yandex.com]]."
	else
		content += "\nTranlasted summary is currently not available."
	end

	# Add hidden ID
	id = content_by_key(scenario, "id")
	content += "{{html clean=\"false\"}}<span id=\"hidden-id\" style=\"display: none;\">#{id}</span>{{/html}}"

	return content
end

def content_by_key(dataset, key)
	# This helper function returns the value by a key from a given json object
	# Param dataset: json object
	# Param key: string, key of a field inside the json object
	# Example: content_by_key(scenario, "title") returns the title of a scenario

	# If dataset contains the key
	if dataset[key].nil? == false		
		# If field contains array
		if dataset[key].kind_of?(Array)
			if dataset[key].empty? == false
				# If field not empty
				content = dataset[key]
			else
				# If content field is empty
				content = Array.new
			end		
		else
			# If field contains string
			if dataset[key].empty? == false
				# If field not empty
				content = dataset[key]
			else
				# If field is empty
				content = ""
			end		
		end
	else
		$log.error("Could not read '#{key}' field from .json file. This should be generated by scraper.")
	end
	return content
end

def build_list_by_key(key, hash_arr, headline, new_line)
	# DEPRECATED
	# Function returns an array as xWiki list
	content = ""
	content = "**#{headline}**" + "\n"
	if hash_arr[key].empty? == false
		hash_arr[key].each { |item| content += "* #{item}\n" }
		new_line.times { content += "\n" }
	end
	return content
end

def check_for_existing_page(username, password, title, url, wording)
	# This function uses a given 'url' to check wheter a xWiki page already exists
	# Param username, password: strings, your login credentials
	# Param title: string, title of the scenario for string comparison
	# Param url: string, the url of the specific scenario (xWiki page)
	# Param wording: string, placeholder for different use cases
	# Return: boolean, page exists (true), page does not exist (false)

	# Short title for log info
	short_title = build_short_title(title)

	# Build HTTP GET request
	request = Typhoeus::Request.new(
		url,
		ssl_verifypeer: false,
		method: :get,
		userpwd: "#{username}:#{password}",
		headers: { Accept: "application/json; charset=utf-8"}
	)

	# Handling HTTP errors
	request.on_complete do |response|
		if response.success?
			#$log.info("Erfolg")
		elsif response.timed_out?
			$log.error("Time out: Couldn't check for existing page.")
		elsif response.code == 0
			$log.fatal("No HTTP response: #{response.return_message}. Couldn't check for existing page.")
		else
			# page does not exist - response.code => 404
		end
	end		

	# Response object is set after request is run.
	# Response represents an HTTP response
	request.run
	response = request.response			

	# If the page doens't exist, XWiki returns code 404.
	# If return code is something else, check the titles for equality
	if response.code == 404		
		page_exists = false
	else
		response = JSON.parse(response.body)
		check_title = CGI.unescapeHTML(response['title'])
		if title == check_title
			page_exists = true

			# Only write to log, if wording parameter is filled
			if wording.empty? == false
				modifier = response['modifier'].to_s
				modifier = modifier.gsub("XWiki.","") if modifier.empty? == false
				date = response['created']
				date = Time.at(date/1000.0).strftime "%d.%m.%Y"
				$log.warn("#{wording} already exists: #{short_title}. (Last mod.: #{date} by #{modifier})")
			end
		end	
	end
	return page_exists
end

def ask_to_overwrite()
	# If a page already exists, the user is asked to overwrite it.
	# You can bypass the question to overwrite by setting the constants on program start
	if ASK_TO_OVERWRITE == true
		# The normal way
		overwrite_page = get_parameter_from_option_or_ask($options[:overwrite_page], "Overwrite it? [y/n] : ", "n") == "y"
	else
		if OVERWRITE == true
			#$log.info("Overwriting bec. OVERWRITE is set to true.")
			overwrite_page = true
		else
			#$log.info("No overwriting bec. OVERWRITE is set to false.")
			overwrite_page = false
		end
	end
	return overwrite_page
end

def upload_scenario(username, password, title, parent, content, url, wording)
	# This function uploads a given scenario to xWiki. It uses XWiki API and 'Typhoeus' gem for http requests
	# Param username, password: strings for logging in to xWiki. Make sure the account has sufficient rights
	# Param title: string, title including special characters, used to set the title of the scenario
	# Param parent: string, parent of the current scenario, e.g. "AsLehrerOnline.WebHome"
	# Param content: string containing the markup-formatted scenario
	# Param url: string, url containing the scenario title without special characters. 
	# Param wording: string for logging which kind of page is uploaded (mainpage or subpage)

	# Short title for log info
	short_title = build_short_title(title)

	# Build HTTP PUT request 
	request = Typhoeus::Request.new(
		url,
		ssl_verifypeer: false,
		method: :put,
		userpwd: "#{username}:#{password}",
		headers: {'Content-Type'=> "application/x-www-form-urlencoded;charset=UTF-8"},
		body: {title: title, content: content, parent: parent}
	)

	# Handling HTTP success and errors
	request.on_complete do |response|
		if response.success?
			$log.info("#{wording} uploaded: #{short_title}")
		elsif response.timed_out?
			$log.error("Time out: #{wording} not uploaded: #{short_title}")
		elsif response.code == 0
			$log.fatal("Could not get http response while uploading #{wording}: #{response.return_message}")
		else
			$log.fatal("HTTP request failed while uploading #{wording.downcase}. Code: #{response.code.to_s}")
		end
	end
	request.run
end

def upload_translation(username, password, title, content, url, wording)
	# This function uploads a translation of a scenario. It uses XWiki API and 'Typhoeus' gem for http requests
	# See the comments in the main program to understand the architecture of xWiki
	# Param username, password: strings for logging in to xWiki. Make sure the account has sufficient rights
	# Param title: string, title including special characters, used to set the title of the scenario
	# Param content: string containing the markup-formatted scenario
	# Param url: string, url containing the scenario title without special characters. 
	# Param wording: string for logging which kind of page is uploaded (mainpage or subpage)
	# Note: Translations don't carry parent information so 'upload_translation' is slightly different to upload_scenario

	# Build HTTP PUT request 
	request = Typhoeus::Request.new(
		url,
		ssl_verifypeer: false,
		method: :put,
		userpwd: "#{username}:#{password}",
		headers: {'Content-Type'=> "application/x-www-form-urlencoded;charset=UTF-8"},
		body: {title: title, content: content}
	)

	# Handling HTTP errors
	request.on_complete do |response|
		if response.success?
			$log.info("#{wording} uploaded.")
		elsif response.timed_out?
			$log.error("Time out: #{wording} not uploaded.")
		elsif response.code == 0
			$log.fatal("Could not get http response while uploading #{wording}. #{response.return_message}")
		else
			$log.fatal("HTTP request failed while uploading #{wording.downcase}. Code: #{response.code.to_s}.... #{response.return_message}")
		end
	end
	request.run
end

def upload_tags(username, password, tags, mainpage_url)
	# This function uploads scenario tags.
	# Param username, password: strings for logging in to xWiki. Make sure the account has sufficient rights
	# Param tags: array of strings, each string represents one tag
	# Param mainpage_url: url of the scenaio (mainpage). 
	# Note: Tags are global for a scenario which means that you can not set different tags for diff. translations

	# Uploading tags requires a differing url
	url = mainpage_url + "/tags"

	# Tags are built as comma seperated string and uploaded. Uploading tags to XWikki can be a pain, see URL below.
	# https://stackoverflow.com/questions/46715730/uploading-spaced-tags-via-xwiki-api/46715731#46715731
	tags = tags.join(",").gsub(" ", "\n")

	# Build HTTP PUT request 
	request = Typhoeus::Request.new(
		url,
		ssl_verifypeer: false,
		method: :put,
		userpwd: "#{username}:#{password}",
		headers: {'Content-Type'=> "application/x-www-form-urlencoded;charset=UTF-8"},
		body: {tags: tags}
	)

	# Handling HTTP errors
	request.on_complete do |response|
		if response.success?
			#$log.info("Tags uploaded.")
		elsif response.timed_out?
			$log.error("Time out: Tags not uploaded.")
		elsif response.code == 0
			$log.fatal("Could not get http response while uploading Tags. #{response.return_message}")
		else
			$log.fatal("HTTP request failed while uploading Tags. Code: #{response.code.to_s}")
		end
	end
	request.run
end

# ----- Main program -----

# Check username
if (defined?(USERNAME)).nil? == true || USERNAME.empty? == true
	$log.fatal("No username found. Enter username in .rb file")
	exit
end

# Check password
if (defined?(PASSWORD)).nil? == true || PASSWORD.empty? == true
	$log.fatal("No password found. Enter password in .rb file")
	exit
end

# Check space prefix
if (defined?(SPACE_PREFIX)).nil? == true
	$log.fatal("Constant space prefix does not exist. Enter space prefix in .rb file")
	exit
end

# Check space url
if (defined?(SPACE_URL)).nil? == true || SPACE_URL.empty? == true
	$log.fatal("No space url set. Enter space url in .rb file")
	exit
end

# Let user choose files to upload
filenames = list_files()

# For each choosen file do
filenames.each do |filename|
	data, success = parse_json(filename)
	next if success == false

	# For each scenario in .json file do
	data['scenarios'].each_with_index do |scenario, i|
		
		# ----- Upload scenario (mainpage) -----
		# If you upload a page to xWiki, it is initially uploaded without any language info 
		# Because you can't provide any language infos at this early step, xWiki marks the scenario with "default language"
	
		# ---- MnSTEP or LehrerOnline? ----
		# Allow checking for scenario source by boolean
		source = content_by_key(data, "source")
		mnstep, lehreronline = false, false
		mnstep = true if source == "MnSTEP"
		lehreronline = true if source == "LehrerOnline"

		# ----- Title and language -----
		title = content_by_key(scenario, "title") if mnstep
		title = content_by_key(scenario, "title_de") if lehreronline		
		language = content_by_key(data, "language")			

		# ----- Parent -----
		# Each scenario page will be a child of a parent space
		parent = SPACE_PREFIX + source + ".WebHome"

		# ----- Content of the scenario (mainpage) -----
		content = build_content_mnstep(scenario, translations, language) if mnstep 
		content = build_content_lehreronline(scenario, translations, language) if lehreronline

		# ----- Build URL, check for existing page and upload -----
		mainpage_url = build_url(SPACE_PREFIX, SPACE_URL, source, title)
		mainpage_exists = check_for_existing_page(USERNAME, PASSWORD, title, mainpage_url, "Mainpage")
		overwrite_page = ask_to_overwrite() if mainpage_exists
		if mainpage_exists == false || overwrite_page == true
			upload_scenario(USERNAME, PASSWORD, title, parent, content, mainpage_url, "Mainpage")
		end

		# ----- Upload same content as translation pages (main language)-----
		# XWiki is configured for mulitlingual content. In the previous step we uploaded the mainpage which ...
		# was marked as 'default language' by XWiki, because we can't submit language info at this early step.
		# In case of Mnstep we have to upload at least one translation page, namely the 'en' version.
		# In case of 'LehrerOnline' we have to upload two translation pages for 'de' (main language) and 'en'.
		# In this step we will upload ONE translation for the main language, 'en' (Mnstep) and 'de' (LehrerOnline)
		# In a step below, we will cover exception cases like LehrerOnline which will has 'en' as second language.

		# Note: If we upload translation pages, we have to make sure, that their mainpages exists.
		# Otherwise XWiki will generate ghost pages. So in this step, we upload the same(!) content as a translation page.
		# This will ensure that content is online, even if the upload of tranlation page fails
		# Note: Translations don't carry parent information, so 'upload_translation' is slightly different to 'upload_scenario'
		mainpage_exists = check_for_existing_page(USERNAME, PASSWORD, title, mainpage_url, "")
		if mainpage_exists
			translation_url = mainpage_url + "/translations/#{language}"
			translationpage_exists = check_for_existing_page(USERNAME, PASSWORD, title, translation_url, "Translation (#{language})")
			overwrite_translation = ask_to_overwrite() if translationpage_exists
			if translationpage_exists == false || overwrite_translation == true
				upload_translation(USERNAME, PASSWORD, title, content, translation_url, "Translation (#{language})")
			end
		else
			# This will seldom happen, if mainpage failed to upload
			$log.error("Could not upload translation page. Mainpage doesn't exist.")
		end

		# ----- Translation page for LehrerOnline -----
		# LehrerOnlie scenarios are written in german. We decided to provide at least an english abstract.
		# Those abstracts are uploaded as an english translation page in this step.
		# Note: Translations don't carry parent information so 'upload_translation' is slightly different to upload_scenario
		if lehreronline && mainpage_exists
			abstract = build_abstract_lehreronline(scenario)
			translation_title = content_by_key(scenario, "title") # now the english title
			translation_url = mainpage_url + "/translations/en"
			translationpage_exists = check_for_existing_page(USERNAME, PASSWORD, title, translation_url, "Translation (en)")
			overwrite_translation = ask_to_overwrite() if translationpage_exists
			if translationpage_exists == false || overwrite_translation == true
				upload_translation(USERNAME, PASSWORD, translation_title, abstract, translation_url, "Translation (en)")
			end
		end

		# ----- Tags -----	
		# Upload scenario-tags if field is filled and mainpage exists
		# Note: in xWiki, tags are global for a scenario. So each translations has the same tags
		tags = content_by_key(scenario, "bs_tags")
		if tags.nil? == false && tags.empty? == false
			mainpage_exists = check_for_existing_page(USERNAME, PASSWORD, title, mainpage_url, "Tags (maybe)")
			overwrite_tags = ask_to_overwrite() if mainpage_exists
			if mainpage_exists && overwrite_tags == true
				upload_tags(USERNAME, PASSWORD, tags, mainpage_url)
			else
				# This will seldom happen, if mainpage failed to upload
				$log.error("Could not upload tags. Mainpage doesn't exist or user aborted.")
			end
		end # tags
	end # scenarios
end # files

puts
filenames.length > 1 ? ($log.info("All files uploaded.")) : ($log.info("File uploaded."))