# ---- Program info ----
# The 'xwiki_slurper' is used to download articles from from a xWiki environment.
# In case of eSIT4SIP, the program downloads scenarios from eSIT4SIP xWiki.
# The scenarios will be collected in a json file (default: articles.json) and saved as HTML.
# You can use the articles.json to upload the scenarios to fuseki (triple store) via sparql_uploader
# The attachments of a scenario are saved too.
# Furthermore we extract the navigation tags (see NAVIGATION_PAGE) to build search facets for www.esit4sip.eu
# The navigation tags are saved in a json file (default: tags.json)


# The program uses HTTP-requests and the xWiki-API to download scenario-pages.

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
# Output a summary of success and errors at the end
# Re-implement the fetch decision. Fetching is only done, when scenario has changes

require 'cgi'
require 'date'
require 'digest'
require 'json'
require 'logger'

require 'mechanize'
require 'nokogiri'
require 'typhoeus'

# Login
# For each download you have to provide a login
# Make sure your account has enough rights
USERNAME = ""
PASSWORD = ""

# Domain: Where is your wiki located at?
BASE_URL = "https://wiki.yourdomain.eu"

# Navigation page
# NAVIGATION_PAGE: To build search facets on www.esit4sip.eu, navigation tags are defined in a xwiki page.
# The tags are furhtermore used to map the tags from a more "cryptic style"	 to "plain text"
# FETCH_NAVIGATION_PAGE: Decide wheter you want to parse this page or not
# We provide you a shortened version of our navigation tags page to test the functionality. See: navigation page example.txt
NAVIGATION_PAGE = "https://wiki.yourdomain.eu/bin/view/Steps/NavigationTagsNew/"
FETCH_NAVIGATION_PAGE = false

# Space names
# Here you can define the spaces from which article/scenario children are downloaded
SPACES = ["MyContent", "MyArticles"]

# Directories
# OUT_DIR: output files (json, html) are saves here
# ATTACHMENTS_DIR: if scenario contains attachmets, they are saved in OUT_DIR/ATTACHMENTS_DIR
OUT_DIR = "out"
ATTACHMENTS_DIR = "attachments"

# Download attachments
# Set constant to false if you don't want to download scenario attachments
DOWNLOAD_ATTACHMENTS = false

# The name of the file containing the downloaded scenarios
# The file will be saved at OUT_DIR/filename.json
ARTICLE_FILE = "articles.json"

# Directory where the log file will be saved
LOG_DIR = "log"

# On www.esit4sip.eu, the scenarios are listed by their headlines and a short teaser.
# Here you can choose the length of the teaser/ description.
DESCRIPTION_LENGTH = 250;

# A scenario can have multiple translations
# Here you can choose if you want to download those translations
FETCH_TRANSLATIONS = true

# Class for logging in console AND log file
# Since this program runs on a server, a log to file is recommended
class MultiIO
  def initialize(*targets)
     @targets = targets
  end

  def write(*args)
    @targets.each {|t| t.write(*args)}
  end

  def close
    @targets.each(&:close)
  end
end

class String
	def not_empty?
		!self.empty?
	end
end

def get_overview_url(space)
	# On esit4sip-XWiki we use the concept of nested pages. See 'Content Organization' in XWiki documentation.
	# This function generates the URL by which we can get a list of children generated under a father-space.
	return "#{BASE_URL}/rest/wikis/xwiki/spaces/#{space}/pages/WebHome/children"
end

def scraper_get_page(url, scraper, trial, wording)
	# This function returns a GUI page as mechanize node set
	# Param url: string, a URL pointing to a XWiki GUI page
	# Param scraper: meachanize object
	# Param trial: integer, number of prev. trials, used for recursion
	# Recursion: if parsing of page fails it is retried after a certain time (see timer)
	# Return: the GUI-page as a mechanize node set

	filename = (CGI.unescape(File.basename(url)))
	info = "Fetch #{wording} "
	info.prepend("-- ").concat(filename) if wording == "attachment"

	begin
		result = scraper.get(url)
		$log.info(info)
	rescue Timeout::Error
		if trial <= 3
			$log.error("Timeout while fetching #{wording}!")
			timer(10)
			scraper_get_page(url, scraper, trial+1, wording)
		else
			$log.error("Timeout while fetching #{wording}! Moving on bec. couldn't fetch #{url} ")
			result = nil
		end
	rescue SocketError => details
		if trial <= 3
			$log.fatal("Couldn't fetch #{wording}. Check your internet connection. Details: #{details}")
   			timer(25)
   			scraper_get_page(url, scraper, trial+1, wording)
   		else
			$log.fatal("Couldn't fetch #{wording}. Check your internet connection. Details: #{details}")   			
			result = nil   			
   		end
	rescue Mechanize::ResponseCodeError => e
		if e.response_code == "404"
			$log.error("Couldn't fetch #{wording}. Net::HTTPNotFound (404) for #{url}")
		else
			$log.error("Couldn't fetch #{wording}. Unknown exception for #{url}. Message: #{e.inspect}")
		end
	end
	return result
end

def timer(times)
	# Function which prints a countdown to console
	# Used to retry page fetching after a certain time.
	print("Retry in: ")
	times.downto(0) do |i|
		print "#{i} "
		sleep 1
	end		
	puts
end

def truncate(content, max, suffix)
	# Truncate naturally
	# EG.: I am a sample phrase to show the result of this function.
	# NOT: I am a sample phrase to show the result of th...
	# BUT: I am a sample phrase to show the result of...

	# Param content: string, contains the content to be truncated
	# Param max: integer, the max amount of characters
	# Param suffix: string, the suffix tp be attached on the end e.g. "..."

	if content.nil? == false
		if content.length > max
			truncated = ""
			collector = ""
			content = content.split(" ")
			content.each do |word|
				word = word + " " 
				collector << word
				truncated << word if collector.length < max
			end
			truncated = truncated.strip.chomp(",").concat(suffix)
		else
			truncated = content
		end
	end
	return truncated
end

def get_page_by_url(username, password, url, type, wording)
	# Returns a single page by a given url in a requested type.
	# The function is mainly used to return results of XWiki API
	# Param username, password: strings, XWiki login credentials
	# Param url: string, the (restful) url 
	# Param type: string, can be json, xml or x-www-form-urlencoded format.
	# Param wording: string, makes logging dynamic

	# Build HTTP GET request
	request = Typhoeus::Request.new(
		url,
		ssl_verifypeer: false,
		method: :get,
		userpwd: "#{username}:#{password}",
		headers: { Accept: "application/#{type}; charset=utf-8"}
	)

	# Handling HTTP errors
	request.on_complete do |response|
		if response.success?
			$log.info("Fetch #{wording}.")
		elsif response.timed_out?
			$log.error("Timeout: Couldn't fetch #{wording}.")
		elsif response.code == 0
			$log.fatal("No HTTP response: #{response.return_message}. Couldn't fetch #{wording}.")
		else
			# page does not exist - response.code => 404
		end
	end		

	# Run the request
	# Response object is set after request is run. It represents a HTTP response
	request.run
	response = request.response.body

	# Parse the response if the type is "json"
	response = parse_json(response, "get_page_by_url") if type == "json"
	return response
end

def parse_json(content, wording = "")
	# Param content: json string to be parsed to ruby hash
	# Param wording: string, makes logging dynamic
	# Return: hash
	begin
		JSON.parse(content)
	rescue JSON::ParserError => e
		if wording.empty?
			$log.fatal("Could not parse json. Reason: #{e}")
		else
			$log.fatal("Could not parse json while working on '#{wording}'. Reason: #{e}")
		end
	end	
end

def scenario_title_url(page, space)
	# From a API request we obtained the overview of child sites of the mainspace.
	# Now we extract the title and url's to these child sites.
	# Param page: hash, contains info about the mainspace and its child sites
	# Param space: string, for string comparison to ignore the backling to mainspace
	# Return: Hash in the format title:url

	title_url = Hash.new
	title, url = "", ""

	page['pageSummaries'].each do |summary|
		title = summary['title']
		next if title == "Preferences"

		summary['links'].each do |link|
			url = link['href']
			url.sub!("http://localhost:8080", BASE_URL)
			next if url.include?("#{space}/pages") # url to mainpage
			url = url if url.end_with?("WebHome")
		end
		title_url[title] = url
	end
	return title_url
end

def write_file(filename, content, folder, encoding = "")
	# This function writes a content to file in a given directory
	# Param filename: string, the name AND file extension
	# Param content: string, the content to be saved
	# Param folder: string, name of the directory where file to be saved
	# Param encoding: string, the encoding of the file
	# Note: if you want to create nested directories use 'fileutils' instead.
	Dir.mkdir(folder) if File.directory?(folder) == false
	filename = "#{folder}/#{filename}"
	File.open(filename, "w#{encoding}") { |f| f.write(content) }
	$log.info("File saved: #{filename}")
end

def fix_attachment_paths(content, attachments, id)
	# Param content: contains node set of '#xwikicontent' container.
	# This node set contains <a> and <img> elements pointing to attachments.
	# Their 'href' or 'src' attribute points to https://...bin/download/...
	# We want to replace their absolute path by an relative path (here 'data/')
	# Param attachments: We can do is with 'attachments' hash containing filename and url.
	# CGI unescape: URL-decode a string with encoding (optional).

	images = content.css('img')
	attachments.each do |filename, url|
		images.each do |img|
			src = img.attribute('src')
			src_unes = CGI.unescape(src.to_s)
			if src_unes.include?(filename) && src_unes.include?("bin/download")
				img['src'] = "data/#{ATTACHMENTS_DIR}/#{id}/#{filename}"
			end
		end
	end

	anchors = content.css('a')
	attachments.each do |filename, url|
		anchors.each do |anchor|
			href = anchor.attribute('href')
			href_unes = CGI.unescape(href.to_s)
			if href_unes.include?(filename) && href_unes.include?("bin/download")
				anchor['href'] = "data/#{ATTACHMENTS_DIR}/#{id}/#{filename}"
			end
		end
	end
	return content
end

def read_scenario_tags(page)
	# Returns the downcased tags of a scenario as array
	# Param page: hash representing a scenario page
	# Note: We onlye append tags starting with "bs_" (babystep tags)
	tags_collector = Array.new
	tags = page['tags']
	tags.each do |tag|		
		tag = tag['name']
		tags_collector << tag if tag.start_with?("bs_")
	end
	return tags_collector
end

def read_scenario_attachments(page)
	# Returns hash array of scenario attachments
	# Param page: hash representing a scenario page
	# Return: hash in the format: filename:url
	filename_url = Hash.new
	attachments = page['attachments']
	attachments.each do |attachment|
		title = attachment['name']
		url = attachment['xwikiAbsoluteUrl']
		if url.not_empty? && title.not_empty?
			filename_url[title] = url
		end
	end
	$log.info("No attachments used") if filename_url.empty?
	return filename_url
end

def read_navigation_tags(page)
	# www.esit4sip.eu uses a filter system with facets
	# The facets are read from a special page, see NAVIGATION_PAGE constant
	# We collect the navigation tags (facet names) by analyzing this page.
	# Param page: hash representing the navigation-page
	# Return: hash in the format {"groupname": "Language", "tags": {"bs_Language_English": "english"}
	# See the saved list in tags.json
	content = Array.new()
	headlines = page.css('#xwikicontent h2')
	$log.error("No headlines found in 'Navigation Tags' page.") if headlines.empty?

	headlines.each do |h|
		groupname = h.text
		tags = Hash.new
		
		h_next = h.next		
		if h_next.nil? == false
			# A headline is followed by a <ul> list.
			# But sometimes <p> appear between both.
			# To ignore them we have to wander till we find a <ul>.
			while h_next.name != "ul"
				h_next = h_next.next
				if h_next.nil? == true
					$log.error("Could not find <ul> list after groupname: #{groupname}.")
					break
				end
			end
		end
		if h_next.name == "ul"

			list = h_next.css('li')
			list.each do |li|
				li_children = li.children
				if li_children.empty? == false
					tag = {}

					# a list element is built like this:
					# bs_Domain_Arts (12) Arts
					# syntax: key / counter  / value
					key, value = "", ""
					counter = 0

					li_children.each do |node|
						node_name = node.name.to_s
						node_text = node.text.strip.to_s
						if node_name == "em"
							key = node_text
						elsif node_name == "strong"
							value = node_text
						elsif node_name == "a"
							counter = node_text.to_i
						end
					end
					# Are key and value filled? Is counter >= 0?
					if key.empty?
						$log.error("Could not get tag in groupname: #{groupname}. Reason: bs_Tag is missing")
					elsif value.empty?
						$log.error("Could not get tag in groupname: #{groupname}. Reason: Tag title is missing") 
					elsif counter == 0
						$log.warn("Ignored tag '#{key}', because its not used in scenarios") 
					else
						# Everything is fine. Key and value are found.
						tags[key] = value.delete("^a-zA-Z0-9\_ ")
					end
				end
			end #li
		end
		if tags.empty? == false
			$log.info("Tags added for groupname: #{groupname}")
			content << {"groupname": groupname, "tags": tags}
		else
			$log.error("No tags added for groupname: #{groupname}")
		end
	end
	return content
end

def read_file(filename, encoding)
	# Function reads a file by filename and enconding
	# Param filename: string, path to file and filename + extension
	# Param encoding: string, encoding of the file
	begin
		file = File.read(filename, :encoding => encoding)
		$log.info "Successfully read file '#{filename}'."
	rescue => error
		file = nil
		$log.warn "Could not read file '#{filename}'. #{error}"
	end
	return file
end

def get_scenario_hidden_id(gui_url, scraper)
	# See docu on function call
	page = scraper_get_page(gui_url, scraper, 0, "html for hidden id")
	content = page.css('#xwikicontent').children
	id = content.css('#hidden-id').text
	return id
end	

def scenario_to_file(gui_url, scraper, attachments, id)
	# This function is used to save the GUI page of a scenario to file
	# Param gui_url: string, url pointing to a GUI page of a scenario
	# Param scraper: mechanize object
	# Param attachments: hash in the format: filename:url
	# Param id: string, the ID of the scenario

	# Scrape scenario by gui url and get 'xwikicontent' element
	page = scraper_get_page(gui_url, scraper, 0, "html gui page")
	content = page.css('#xwikicontent').children

	# Fix attachment paths
	content = fix_attachment_paths(content, attachments, id)
	
	# Write to file
	filename = id + ".html"
	write_file(filename, content, OUT_DIR, ":UTF-8")

end

def translation_to_file(translation_gui_url, scraper, attachments, id, language)
	# DEPRECATED
	# This function is used to save the GUI page of a scenario-translation to file
	# Param gui_url: string, url pointing to a GUI trnaslation page of a scenario
	# Param scraper: mechanize object
	# Param attachments: hash in the format: filename:url
	# Param id: string, the ID of the scenario
	# Param language: string, e.g. 'de', 'en'
	# A filename can look like: 0fc87586329defcf386a7d9a7cf96b5a_en

	# Extract the content from the Gui-page as node pair
	# Fix attachment paths and then save the node as html
	gui_page = scraper_get_page(translation_gui_url, scraper, 0, "translation gui")
	content = gui_page.css('#xwikicontent').children
	content = fix_attachment_paths(content, attachments, id)
	filename_translation = id + "_" + language + ".html"
	write_file(filename_translation, content, OUT_DIR, ":UTF-8")

	# GUI title	
	translation_gui_title = gui_page.css('#document-title').text
	return translation_gui_title

end

def collect_article(rest_url, scenario, space, attachments, scraper, navigation_tags, scenario_tags, id, handwritten)
	# This function collects all relevant info of a scenario page (article)
	# Param rest_url: string, url used to get the scenario page per API. Used to get the tags here
	# Param scenario: hash, representing the scenario (json) page
	# Param space: string, name of the father spce, used for string replacements
	# Param attachments: hash in the format: filename:url
	# Param scraper: mechanize object
	# Param navigation_tags: hash in the format {"groupname": "Language", "tags": {"bs_Language_English": "english"} See read_navigation_tags()
	# Param scenario_tags: array of tags found in a scenario
	# Param id: string, the ID of the scenario
	# Param handwritten: boolean, if the page was handwritten by authors or uploaded by xwiki_uploader
	# Return: scenario/article as hash

	# ---- ID / Version ----
	xwiki_id = scenario['id']
	scenario_version = scenario['version']

	# ---- Title / Name ----
	clean_title = scenario['space'].gsub("#{space}.", "")
	ugly_title = scenario['title']

	# ---- Date ----
	date_created = scenario['created']
	date_created = Time.at(date_created/1000)
	date_created = date_created.strftime("%Y-%m-%d")

	# ---- Save attachments (images, documents) ----
	if DOWNLOAD_ATTACHMENTS
		attachments.each do |filename, url|
			file = scraper_get_page(url, scraper, 0, "attachment")
			file = file.save! "#{OUT_DIR}/#{ATTACHMENTS_DIR}/#{id}/#{filename}" if file.nil? == false
		end
	end	

	# ---- Description ----
	# We get the description from the field 'content'
	# Description is the json content text minus the 'ugly_title'
	# Description is the content between italic markers '//' (regex)
	# The description is then truncated to a globally given length	
	wiki_content = scenario['content'].sub("= #{ugly_title} =", "")		
	description = wiki_content[0...DESCRIPTION_LENGTH+50]
	marker = "//"
	description = description[/#{marker}(.*?)#{marker}/m, 1]

	# If author forgot to make the description italic
	if description.nil?
		description = wiki_content.gsub!(/[\/\=\*]/,"") 
		description = truncate(description, DESCRIPTION_LENGTH, "...")			
	end

	# ---- Tags of scenario ----
	# DEPRECATED bec. tags are incoming a parameter
	#tags_url = rest_url + "/tags"
	#tags_page = get_page_by_url(USERNAME, PASSWORD, tags_url, "json", "tags page")
	#scenario_tags = read_scenario_tags(tags_page) # Array of tags

	# Build hash
	article = {"id": id, "xwiki_id": xwiki_id, "title": ugly_title, "date": date_created, "summary": description, "version": scenario_version, "translations": [], "handwritten": handwritten}

	# Add groupnames and matching tags to article
	# Example: "subject": ["social science"], "devices": [], ...
	navigation_tags.each do |element|
		element = element.to_h
		groupname = element[:groupname].downcase.gsub(' ', '_')
		article[groupname] = []

		hits = Array.new
		nav_tags = element[:tags].to_h
		nav_tags.each do |key, val|
			# Does the array (of scenario tags) contain one of the tags defined in 'navigation tags?'
			if scenario_tags.include? key
				hits << val
				#p "match at #{key}" 
			end
		end
		article[groupname] = hits
	end
	$log.info("Navigation tags processed.")

	# More tags which should be saved in articles.json but not mentioned in tags.json
	# If we would list all affordances or tools, the filter-list would contain too many options
	more_tags = ["Domain", "Affordances", "Tool"]
	more_tags.each do |more_tag|
		
		bs_style = "bs_" + more_tag + "_"
		groupname = more_tag.downcase.gsub(' ', '_')
		article[groupname] = []

		hits = Array.new
		scenario_tags.each do |scenario_tag|
			if scenario_tag.downcase.include? bs_style.downcase
				hits << scenario_tag.sub(bs_style, "")
				#puts "#{more_tag} found: #{scenario_tag.sub(bs_style, "")}"
			end
		end
		article[groupname] = hits
	end
	$log.info("Further tags processed.")

	return article
end

def process_translation(rest_url, rest_page, attachments, language, scraper, id, translation_gui_url)

	# This function collects all relevant info of a scenario trnaslation page
	# Param rest_url: string, url used to get the scenario translation page per API.
	# Param rest_page: hash, representing the scenario trnaslation (json) page
	# Param attachments: hash in the format: filename:url
	# Param language: string, e.g. 'de', 'en'
	# Param scraper: mechanize object
	# Param id: string, the ID of the scenario
	# Param translation_gui_url: string to the gui page of the translation
	# Return: translation as hash

	# ---- ID / Version ----
	# param ID is used to fix the attachment paths
	translation_version = rest_page['version']

	# ---- Gui page as NODE ----
	# Extract the content from the Gui-page as node pair
	# Fix attachment paths and then save the node as html
	gui_page = scraper_get_page(translation_gui_url, scraper, 0, "translation gui")
	content = gui_page.css('#xwikicontent').children
	content = fix_attachment_paths(content, attachments, id)
	filename_translation = id + "_" + language + ".html"
	write_file(filename_translation, content, OUT_DIR, ":UTF-8")

	# ---- GUI title ----	
	# The title is extracted from the Gui page
	gui_title = gui_page.css('#document-title').text

	# ---- Description ----
	# Description is the whole content text minus the 'gui_title'
	# The description is then truncated to a globally given length
	description = content.text.strip.sub(gui_title, "")
	description = truncate(description, DESCRIPTION_LENGTH, "...")		

	translation = {"title": gui_title, "language": language, "summary": description, "version": translation_version}
	return translation
end

def build_translation_rest_url(links)
	# Building the restful url to the translation seems simple in the first moment. 
	# Just add your language code to your restful-url like ...pages/WebHome/translations/en
	# But dependent of scenario creation, XWiki can let a translation point back to WebHome
	# So a translation-url can look like this: .../pages/WebHome. So we have to iterate over 
	# all translation-hrefs (translation & history) and get the one that does not end with history.
	# After replacing the localhost we can scrape the translation.	
	translation_rest_url = ""
	links.each {|link| translation_rest_url = link['href'] if link['href'].end_with?("history") == false}
	translation_rest_url.sub!("http://localhost:8080", BASE_URL)
	return translation_rest_url	
end

def cli_headline(headline)
	puts "\n--------------- #{headline} ---------------"
end


# ----- Main program -----

# Initialize Logger directory and object
Dir.mkdir(LOG_DIR) unless File.directory?(LOG_DIR)
log_file = File.open("log/log.txt", "a")
$log = Logger.new MultiIO.new(STDOUT, log_file)
$log.formatter = proc { |type, date, prog, msg| "#{type} --: #{msg}\n" }

# Mechanize object, bypass SSL verification
# Limit scraping to once every half-second to avoid IP banning.
scraper = Mechanize.new { |agent| agent.user_agent_alias = 'Windows Chrome' }
scraper.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE 
scraper.history_added = Proc.new { sleep 0.5 }

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

# ---- Get tags and save tags.json ----
# To build esit4sip search facets, 'navigation tags' are defined in a xwiki page.
# We get these tags by scraping this page. Constant 'NAVIGATION_PAGE' contains the url.
if FETCH_NAVIGATION_PAGE
	cli_headline("Fetching Navigation Tags")
	navigation_page = scraper_get_page(NAVIGATION_PAGE, scraper, 0, "Navigation tags page")
	navigation_tags = read_navigation_tags(navigation_page)
	write_file("tags.json", navigation_tags.to_json, OUT_DIR, nil)
else
	navigation_tags = []
end

# ---- Articles ----
# Collect scenario content in 'article' array.
# It contains name, description, id, url, tags, language code...
# The collected data is saved in 'articles.json' later.

# ---- Existing articles.json ----
# Reading and parsing existing articles.json file
# If this file is present we can use it as base for updating data.
# If the file is not present, we have to fetch all from beginning.

=begin
	article_path = OUT_DIR + "/" + ARTICLE_FILE
	article_file = read_file(article_path, "UTF-8")
	if article_file.nil? == false && article_file.empty? == false
		articles = parse_json(article_file, "initialize")
		articles_present = true
	else
		$log.warn("No '#{article_path}' available or empty which allows downloading only modified scenarios. We have to fetch all now.")
		articles = Array.new
		articles_present = false
	end
=end

articles = Array.new

# ---- Existing html files ----
# Normally we skip scenario fetching if articles.json says its up to date
# Skipping would be bad if scenario is present in articles.json but not in file system.
# That's why we get an array of filenames to check wheter a file is present or not.
html_files = Dir.glob("#{OUT_DIR}/*.html")
html_files.map! {|file| File.basename(file,".html")}


SPACES.each do |space|

	# Each space (e.g. AsLehrerOnline) contains many child-pages (scenarios).
	# To find out which children exist, we http-get the space overview and see...
	# what child pages are present. Their title and rest-url are saved in Hash.
	cli_headline("Collect data in space '#{space}'")
	url = get_overview_url(space)
	overview_page = get_page_by_url(USERNAME, PASSWORD, url, "json", "space overview for '#{space}'")
	title_url = scenario_title_url(overview_page, space) # Hash: title:rest-url
	$log.warn("No scenarios found in space '#{space}'.") if title_url.empty?
	puts

	# For all scenarios we know their title plus rest-url
	# Now we can scrape each scenario with its rest-url
	title_url.each do |title, rest_url|
	
		puts
		# ---- Scenario Json ----
		# Http get scenario-json by restful url returned as hash.
		scenario = get_page_by_url(USERNAME, PASSWORD, rest_url, "json", "scenario '#{title}'")

		# ---- Tags of scenario ----
		# Important: We have to check the tags at this early step and check wheter the
		# tag "NO_ICT" is present. It says that a scneario does not use any media.
		# If the tg is present, we can skip the next steps.
		tags_url = rest_url + "/tags"
		tags_page = get_page_by_url(USERNAME, PASSWORD, tags_url, "json", "tags page")
		scenario_tags = read_scenario_tags(tags_page) # Array of tags
		
		if scenario_tags.include?("NO_ICT")
			$log.warn("ABORTING. The scenario does not use any media bec. NO_ICT tag is present.")
			next
		end

		# ---- Read attachments ----
		# Only read what attachments are available. No file-fetching yet!
		# Fetching is done, when changes occured in default scenario or translation.
		# Info: Scenario default page and translations are using the same attachments.
		attachment_url = rest_url + "/attachments"
		attachment_page = get_page_by_url(USERNAME, PASSWORD, attachment_url, "json", "attachment overview")
		attachments = read_scenario_attachments(attachment_page) #returns hash: filename=>url		

		# ---- Scenario GUI URL ----
		# The gui_url points to a user-readable html page
		gui_url = scenario['xwikiAbsoluteUrl']
		
		# ---- Scenario hidden ID ----
		# To get a connection between the local json files and xwiki html-files, we uploaded the ID
		# as a display:none dom element. We use this ID to name the html files and use it in articles.json
		# We us handwritten to show, if a scenario was uploaded by ruby or handwritten by user
		id = get_scenario_hidden_id(gui_url, scraper)
		handwritten = false

		# ---- Handle empty ID ----
		# If a scenario is handwritten, it doesnt have the hidden ID and so an empty id string
		# We can fix it by using the xwiki ID which is converted to Hash by MD5 Digest
		if id.empty?
			scenario_id = scenario['id']
			id = Digest::MD5.hexdigest(scenario_id)
			handwritten = true
		end

		# ---- Write GUI Page to file ----
		# We us the hidden ID, to save the scnearios GUI version as html
		scenario_to_file(gui_url, scraper, attachments, id)

		# ---- Collect article ----
		# Here we get the data about a scenario from the hash and append it to the array for articles.json
		articles << collect_article(rest_url, scenario, space, attachments, scraper, navigation_tags, scenario_tags, id, handwritten)

		# ---- ID / Version ----
		scenario_id = scenario['id']

		# ---- Translations ----
		# A XWiki page can have multiple translations
		translations = scenario['translations']['translations']		

		translations.each do |translation|

			# ---- Language code ----
			language = translation['language']

			# ---- Translation restful ----
			translation_rest_url = build_translation_rest_url(translation['links'])
			translation_json = get_page_by_url(USERNAME, PASSWORD, translation_rest_url, "json", "translation restful (#{language})")

			# ---- Translation GUI URL ----
			translation_gui_url = gui_url + "?language=#{language}"

			# ---- Write GUI translation page to file ----
			translation_new = process_translation(rest_url, translation_json, attachments, language, scraper, id, translation_gui_url)
			articles.each { |article| article[:translations] << translation_new if article[:xwiki_id] == scenario_id }			

		end

		# IMPORTANT: The next code contains a change-management. 
		# The program doesn't download a scenario if the version hasn't changed since the last program-run.
		# Due to spontaneous changes under time pressure the fetching decisions have been disabled
		# TODO: reimplement it
=begin
		# ---- Fetch possibilities ----
		# 1) ABORT: Scenario is present in articles.json and up to date. Fetching is aborted.
		# 2) UPDATE: Scenario is present in articles.json but not up to date. Overwrite it.
		# 3) ADD: Scenario is not present in articles.json. Append it to articles array.
		# 4) START articles.json does not exist on file system. Fetch from beginning.
		# 5) RESTORE: Cannot find html file on file system. Restore it.
		# 6) DELETE: (TODO) In articles.json an scenario appears which is not on server.

		# ---- Obtain scenario (default page) status ---- 
		# For the possibilites described above, we need the status of each scenario.
		# is_present = true if the translation is listed in articles.json
		# up_to_date = true if it's version is the same as the XWiki translation page
		# html_exist = true if the html files for the scenario exists in file system
		is_present = false
		up_to_date = false
		html_exist = false
		if articles_present
			existing_article = articles.find {|art| art['intern_id'] == scenario_id }
			is_present = true if existing_article.nil? == false
			up_to_date = true if existing_article.nil? == false && existing_article['version'] == scenario_version
		end
		html_files.each { |file| html_exist = true if file == id }

		# ---- Fetch decision for Mainpage ----
		if articles_present == true
			if is_present && html_exist
				if up_to_date					
					# 1) ABORT: Scenario is present in articles.json and up to date.
					$log.info("ABORT: Scenario is up to date")
				else
					# 2) UPDATE: Scenario is present in articles.json but not up to date.
					# Recollect the scenario, overwrite files, replace article in hash. 
					# collect_article() will return no translations so they have to be fetched again later
					$log.info("UPDATE: Updating scenario (which causes reloading of translations")
					updated_article = collect_article(rest_url, scenario, space, attachments, scraper, navigation_tags)
					articles.map! { |article| article['intern_id'] == scenario_id ? (updated_article) : (article) }
				end
			elsif is_present && html_exist == false
				# 5) RESTORE: Cannot find html file on file system. Restore it.
				$log.warn("RESTORE: Cannot find html file on file system. Restore it.")
				collect_article(rest_url, scenario, space, attachments, scraper, navigation_tags)
			else
				# 3) ADD: Scenario is not present in articles.json. Append it.
				$log.info("ADD: Scenario is not present yet. Fetch completely")
				articles << collect_article(rest_url, scenario, space, attachments, scraper, navigation_tags)
			end
		else
			# 4) START articles.json does not exist. Fetch from beginning.
			$log.info("START: Fetch scenario from beginning")
			articles << collect_article(rest_url, scenario, space, attachments, scraper, navigation_tags)
		end

		# Fetch translations? For debugging.
		if FETCH_TRANSLATIONS == false
			$log.warn("Fetching translations is deactivated.")
			next
		end

		# ---- Available translations ----
		translations = scenario['translations']['translations']		

		translations.each do |translation|

			# ---- Language code ----
			language = translation['language']

			# ---- Translation restful ----
			translation_rest_url = build_translation_rest_url(translation['links'])
			rest_page = get_page_by_url(USERNAME, PASSWORD, translation_rest_url, "json", "translation restful (#{language})")

			# ---- ID / Version ----
			translation_id = rest_page['id'] # needed?
			translation_version = rest_page['version']

			# ---- Translation status ---- 
			# Get status of translation (see documentation above).
			is_present, up_to_date, html_exist = false, false, false
			
			if articles_present		
				articles.each do |article|
					if article['intern_id'] == scenario_id
						article['translations'].each do |trans|
							if trans['language'] == language
								is_present = true
								if trans['version'] == translation_version
									up_to_date = true
								end
							end
						end
					end
				end
			end
			html_files.each { |file| html_exist = true if file == "#{id}_#{language}" }			

			# ---- Fetch decision for a translation ----
			if articles_present == true
				if is_present && html_exist
					if up_to_date					
						# 1) Abort: Translation is present in articles.json and up to date.
						$log.info("ABORT: Translation is up to date (#{language})")
					else
						# 2) Update: Translation is present in articles.json but not up to date.
						# Fully collect the scenario, overwrite files, replace translation in his article.
						$log.info("UPDATE: Updating translation (#{language})")
						updated_translation = process_translation(rest_url, scenario, rest_page, attachments, language, scraper)
						existing_article = articles.find {|art| art['intern_id'] == scenario_id }
						existing_translation = existing_article['translations'].find { |trans| trans['language'] == language }
						existing_translation.replace(updated_translation)
					end
				elsif is_present && html_exist == false
					# 5) RESTORE: Cannot find html file on file system. Restore it.
					$log.warn("RESTORE: Cannot find html file on file system. Restore it (#{language}).")
					process_translation(rest_url, scenario, rest_page, attachments, language, scraper)
				else
					# 3) ADD: Translation is not present in articles.json yet. Append it. 
					$log.info("ADD: Translation is not present yet. Fetch completely (#{language})")
					translation_add = process_translation(rest_url, scenario, rest_page, attachments, language, scraper)
					
					# Workaround
					# Ruby uses strings for accessing hashes if an article from json was not updated while running this program.
					# After updating an article ruby uses symbols. So if the string code didn't work, the symbol one will. 
					articles.each { |article| article['translations'] << translation_add if article['intern_id'] == scenario_id }
					articles.each { |article| article[:translations] << translation_add if article[:intern_id] == scenario_id }

					# Old workaround
					#existing_article = articles.find {|art| art['intern_id'] == scenario_id }
					#existing_article['translations'] << translation_add if existing_article.nil? == false					
					#if existing_article.nil?
						#existing_article = articles.find {|art| art[:intern_id] == scenario_id }
						#existing_article[:translations] << translation_add
					#end
				end
			else
				# 4) START articles.json does not exist. Fetch from beginning. 
				$log.info("START: Fetch translation from beginning (#{language})")
				translation_new = process_translation(rest_url, scenario, rest_page, attachments, language, scraper)
				articles.each { |article| article[:translations] << translation_new if article[:intern_id] == scenario_id }
			end
		end
=end
	end	
end

# ---- Save articles.json ----

# Set basic json structure
file_content = {"source": "xwiki", "domain": "https://wiki.yourdomain.eu/", "language": "mixed", "scenarios": articles}.to_json

cli_headline("Writing articles.json")
write_file("articles.json", file_content, OUT_DIR, nil)

# ---- Write log to file ----
File.open("log.txt", "w") { |f| f.write($log) }