# ---- Program info ----

# The 'scraper_lehreronline' uses webscraping technologies to fetch teaching activities of 'Lehrer-Online'. 
# Lehrer-Online describes itself as the leading editorial material and service portal for teachers of all types and levels of education. 
# On www.lehrer-online.de teachers will find high-quality and pedagogically tested teaching material that they can use freely and legally in their lessons. 
# Source: https://www.lehrer-online.de/ueber-uns/

# The 'scraper_lehreronline' program opens https://www.lehrer-online.de and uses the search form to find the terms defined in scraper_lehreronline.rb (see KEYWORDS). 
# Then it fetches the results/activities returned by the search. There it analyzes the content of each activity and will save it in appropriate fields in a .json file. 
# The resulting .json files are structured in a way the 'xwiki_uploader' can read and upload the data to the eSIT4SIP-XWiki. 
# Media elements such as e.g. jpg or text files are not downloaded.

# IMPORTANT
# This software only downloads activities (called scenarios here too) with a free-license. 
# It explicitly ignores scenarios offered in their premium program.  
# We guarantee that we maintain the license of the scenarios.

# For a general understanding of ruby webscraping see:
# http://www.nokogiri.org/
# https://github.com/sparklemotion/mechanize

# ---- Developers ----
# Swetlana Blank
# Media and education management
# University of Education Weingarten

# Stella Ehnis
# Media and education management
# University of Education Weingarten

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

require 'date'
require 'digest'
require 'json'
require 'logger'
require 'rubygems'

require 'mechanize'
require 'nokogiri'

DOMAIN = 'https://www.lehrer-online.de'

# ---- Subpages ----
# On LehrerOnline each mainpage is complemented with subpages
# Keep PARSE_SUBPAGES=false; Parsing subpages is experimental 
PARSE_SUBPAGES = false

# ---- Handle links to subpages ----
# There are two approaches: 
# (1) Scrape subpages, upload them and build internal xwiki-subpage-link (true)
# (2) Don't scrape/upload subpages but add an external link pointing to LehrerOnline (false)
# Since this functionality is not implemented yet, case (2) is present by nature
# BUILD_INTERNAL_LINK = false

# ---- Keyword definition ----
# For each keyword in the array, the program will execute a search and fetch the resulting activities.
# You can line multiple strings in the array. Each term will result in a extra .json file named by it.
KEYWORDS = ["Mobile", "Handy", "Digitales Lernen", "Computer", "Medien"]

# ---- Keywords for testing purposes ----
#KEYWORDS = ["smartphone", "tablet", "handy", "Whiteboard", "Suchmaschine"]
#KEYWORDS = ["smartphone", "tablet", "computer"] #3 + 4 premium
#KEYWORDS = ["Computer Medien Umwelt Klimawandel Ohren"] #20
#KEYWORDS = ["Wärmepumpenanlage"] #1 with subpages
#KEYWORDS = ["update"] #3 + 4 premium
#KEYWORDS = ["Fehlfarben und Fehldrucke"] #1 with subpages
#KEYWORDS = ["Handy-Führerschein"] #1 with 7 subpages
#KEYWORDS = ["Klimapolitik"] # 16 with 40+ subpages
#KEYWORDS = ["Mond"] # 48 with 40+ subpages and many premium content

#KEYWORDS = ["Pickel-Alarm - Haut, Mitesser, Pickel"] # check pubertaet.lehrer-online.de
#KEYWORDS = ["Kartoffel"] # check for premium content which should be ignored
#KEYWORDS = ["Onlinesucht"] # check for DGV Scenarios which should be ignored
#KEYWORDS = ["Hygiene in der Pflege"] # check bug of non existent result link
#KEYWORDS = ["Materialsammlung"] check material collections which are ignored

# ---- Expand Ruby Class 'String' ----
class String
	# Adding methods to string-class for method chaining
	# Mainly methods for styling content with markup.

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

	def newline(before, after)
		return "\n" * before + self + "\n" * after
	end

	def prettify_newlines
		# Function reduces exceeded newlines to only \n\n
		# It removes leading and trailing newlines too.
		text = self
		10.downto(3) do |i|
			n = "\n"*i
			text = text.gsub(n, "\n\n")
		end
		return text
	end

	def to_title(type, before, after) 
		# Builds title1, title2... and adds newlines.
		title = "=" * type + " " + self + " " + "=" * type 
		title = title.newline(before, after)
	end
end

def parse_container(content_block, strings_to_exclude)
	# Helper function returns container content (e.g. headlines, text, links, lists tables) formatted as string.
	# It iterates over all child-nodes of a given container and formats content apporpriate to each elements name.
	# Some containers contain headlines which should not be scraped. Parameter 'strings_to_exclude' was made for that.
	# Strings_to_exclude contains comma seperated words which are splitted to array in this function.

	content = ""
	content_block.children.each do |node|
		node_name = node.name.to_s
		node_text = node.text.strip.to_s

		# There are some reasons to skip a node
		# - Skip node if it doesn't contain any text
		# - Skip node if a string_to_exclude matches node_text
		# - Skip node if it contains a buggy comment (LehrerOnline specific)
		skip = false
		skip = true if node_text.empty? == true
		strings_to_exclude.any? { |word| skip = true if node_text == word }
		skip = true if node_text =~ /f:render(.*?)Array/
		next if skip
		
		if node_name == "div"
			content += parse_container(node, strings_to_exclude)
		elsif node_name == "h1" || node_name == "h2" || node_name == "h3"
			content += parse_headline(node).to_title(3,1,1)
		elsif node_name == "p"
			content += parse_paragraph(node, "normal")
		elsif node_name == "span"
			content += parse_paragraph(node, "normal")
		elsif node_name == "text"
			content += parse_text(node, "normal")
		elsif node_name == "strong"
			content += parse_strong(node)
		elsif node_name == "b"
			content += parse_strong(node)
		elsif node_name == "a"
			content += parse_link(node)
		elsif node_name == "ul"
			content += "\n"
			content += parse_list(node, "ul", strings_to_exclude, 1)
			content += "\n"
		elsif node_name == "ol"
			content += parse_list(node, "ol", strings_to_exclude, 1)
		elsif node_name == "table"
			content += parse_table(node)
		elsif node_name == "sub"
			content += parse_sub(node)
		elsif node_name == "sup"
			content += parse_sup(node)
		elsif node_name == "figure"
			#content += parse_figure(node)
		else
			content +=  node.text.split.join(' ')
		end
	end
	return content
end

def parse_table(node)
	# Helper function called by 'parse_container' which returns tables correctly formatted as string.
	# This function is called when 'parse_container' identifies a table. Incoming parameter is <table> node.
	# It iterates over all rows & gets all cells. Afterwards it iterates over all cells and identifies...
	# table-header and table-data by its cell.name. Due to this the cell-content gets formatted with markup.

	content = "\n"
	rows = node.css('tr')
	rows.each do |row|
		cells = row.children
		cells.each do |cell|
			# identify th and td and format it
			cell_type = cell.name.to_s
			cell_type == "th" ? (content += "|=" + cell.text.strip) : (content += "|" + cell.text.strip)
		end
		content += "\n"
	end	
	return content
end

def parse_list(list_node, ul_or_ol, strings_to_exclude, level)
	# Helper function called by 'parse_container' which returns lists correctly formatted as string.
	# This function is called when 'parse_container' identifies a <ul> or <ol> node. Incoming parameters are...
	# <ul> or <ol> as list_node. The list-type is given as string in 'ul_or_ol'. This parameter determines how the list
	# is formatted. Furthermore there is paramter 'strings_to_exclude' which helps to ignore some elements by their text.
	# This function gets all <li>-elements from the list-node and iterates over them. Each <li>-element can contain
	# multiple children (p, text, ul...). So each li-children is formatted per node-name and helper functions.
	# This function works recursive since each list-element can contain further lists. The parameter 'level' was made
	# to handle the correct markup formatting of nested lists.

	content = "\n"
	last_content = ""
	ul_or_ol == "ul" ? (character = "*" * level + " ") : (character = "1" * level + ". ")

	# Get all list elements
	list = list_node.css('li')
	list.each do |li|
		# For each list-element do
		# - Get all child nodes of <li> like div, text, h1, p, a ..
		# - Reset variable 'li_content' for collecting node content
		li_children = li.children
		li_content = ""

		if li_children.empty? == false
			li_children.each do |node|
				# For each <li> child nodes do
				# - Get node name and node content
				# - Skip a node if condition is true (see below)
				# - Collect node content in variable 'li_content'
				node_name = node.name.to_s
				node_text = node.text.strip.to_s

				# There are some reasons to skip a node
				# - Skip node if it doesn't contain any text
				# - Skip node if a string_to_exclude matches node_text
				# - Skip node if it contains a buggy comment (LehrerOnline specific)
				# - Skip node if node_text is the same as previous content
				skip = false
				skip = true if node_text.empty? == true
				strings_to_exclude.any? { |word| skip = true if node_text == word }
				skip = true if node_text =~ /f:render(.*?)Array/
				skip = true if node_text == last_content
				next if skip
				
				if node_name == "div"
					li_content += parse_container(node, strings_to_exclude)
				elsif node_name == "text"
					li_content += parse_text(node, "list")
				elsif node_name == "h1" || node_name == "h2" || node_name == "h3"
					li_content += parse_headline(node) #+ ": ".to_title(3,0,1)
				elsif node_name == "p"
					li_content += parse_paragraph(node, "list")
				elsif node_name == "span"
					li_content += parse_paragraph(node, "list")
				elsif node_name == "strong"
					li_content += parse_strong(node)
				elsif node_name == "b"
					li_content += parse_strong(node)
				elsif node_name == "a"
					li_content += parse_link(node)
				elsif node_name == "ul"
					li_content += "\n"
					li_content += parse_list(node, "ul", strings_to_exclude, level + 1)
					last_content = node_text
				elsif node_name == "ol"
					li_content += "\n"
					li_content += parse_list(node, "ol", strings_to_exclude, level + 1)
					last_content = node_text
				elsif node_name == "table"
					li_content += parse_table(node)
				elsif node_name == "sub"
					li_content += parse_sub(node)
				elsif node_name == "sup"
					li_content += parse_sup(node)
				else
					li_content += node.text.split.join(' ')
				end
			end
			# After parsing <li> child nodes
			# - Add markup character for list type. Done after skipping to avoid empty bullet points.
			# - Remove excessive newlines and add one for the normal newline after a list-element.
			content += character + li_content
			content.strip!
			content += "\n"
		end
	end
	# After whole list: Add newline
	content += "\n"
	return content
end

def parse_headline(node)
	return node.text.strip.split.join(' ')
end

def parse_sub(node)
	return ",,#{node.text.strip},, "
end

def parse_sup(node)
	return "^^,,#{node.text.strip},,^^ "
end

def parse_figure(node)
	# in development
	return ""
end

def parse_text(node, type)
	text = node.text.strip
	text = "" if text.empty? == true
	
	name_next = node.next
	# Stay inline if a, sub, sup
	if name_next.nil? == false
		if name_next.name == "a"
			text += " "
		elsif name_next.name == "sub"
			# nothing
		elsif name_next.name == "sup"
			# nothing
		else
			text += "\n" if type == "normal"
		end
	end

	return text
end

def parse_paragraph(node, type)
	# A paragraph can have children too: text, a, b, span...
	# If p has children send node to parse_container.
	# If p has no children simply read its text. 

	content = ""
	children = node.children
	if children.empty? == false
		content += parse_container(node, ["no-exclude"])
	else
		content += parse_text(node, type)
	end
	return content
end

def parse_strong(node)
	# Helper function parses <strong> and <b> nodes. 
	# Some strongs are used as headlines. This case can be identified if
	# the following element is a <br>. If this is true, then add newline.

	content = ""
	node_text = node.text
	content = "**#{node_text.strip}** " if node_text.not_empty?
	next_node = node.next
	if next_node.nil? == false
		next_name = next_node.name
		content += "\n" if next_name.to_s == "br"
	end
	return content
end

def parse_link(link)
	# Function parses hyperlinks and formats it correctly.
	# It uses the link-text and the url to build markup.	
	content = ""
	link_text = link.text.strip
	link_url = link.attribute('href').to_s
	
	# Although the father-functions got "strings_to_exclude" some elements can pass.
	# That's why those elements get sorted out at this last step too.
	skip = false
	strings_to_exclude = ["Mappe", "Merkliste", "Vorschau"]
	strings_to_exclude.any? { |word| skip = true if link_text == word }

	# Some links are not accessible when scraper is not logged in.
	# The scraper will return '#'. If this happens only link_text is shown.
	if link_url == "#"
		content = link_text + " "
	elsif link_text.not_empty? && link_url.not_empty? && skip == false
		content = "[[#{link_text}>>url:#{link_url}]] "
	end
	return content
end

def get_subpage_urls(nodeset)
	# Ths function identifies if a link leads to a subpage
	# Parameter nodeset is a set of one ore many links
	# Subpage = if a link is 'internal-link' and contains 'seite/ue'

	urls = []
	nodeset.each do |link_node|
		url = link_node.attribute("href").to_s
		is_subpage = url.include? "seite/ue"
		link_class = link_node.attribute('class').to_s
		urls << url if link_class == "internal-link" || link_class == "intern" && is_subpage == true
	end
	return urls
end

def build_short_title(title)
	# Some page titles are too long to generate meaningful log info. 
	# So this function trims a given title to x characters. 
	title.length >= 40 ? (short_title = "#{title[0..40]}...") : (short_title = title)
end

def scraper_get_page(url, scraper, trial, wording)
	# This function returns a GUI page as mechanize node set
	# Param url: string, a URL pointing to a GUI page
	# Param scraper: meachanize object
	# Param trial: integer, number of prev. trials, used for recursion
	# Recursion: if parsing of page fails it is retried after a certain time (see timer)
	# Return: the GUI-page as a mechanize node set

	begin
		result = scraper.get(url)
	rescue Timeout::Error
		if trial <= 3
			$log.error("Timeout while fetching #{wording}!")
			timer(10, trial)
			scraper_get_page(url, scraper, trial+1, wording)
		else
			$log.error("Timeout while fetching #{wording}! Moving on bec. couldn't fetch #{url} ")
			result = nil
		end
	rescue SocketError => details
		if trial <= 3
			$log.fatal("Couldn't fetch #{wording}. Check your internet connection. Details: #{details}")
   			timer(20, trial)
   			scraper_get_page(url, scraper, trial+1, wording)
   		else
			$log.fatal("Couldn't fetch #{wording}. Check your internet connection. Details: #{details}")   			
			result = nil   			
   		end
	rescue Mechanize::ResponseCodeError => details
		if trial <= 3
			$log.fatal("Couldn't fetch #{wording}. Check your internet connection. Details: #{details}")
   			timer(20, trial)
   			scraper_get_page(url, scraper, trial+1, wording)
   		else
			$log.fatal("Couldn't fetch #{wording}. Check your internet connection. Details: #{details}")   			
			result = nil   			
   		end
	end
	return result
end

def timer(times, trial)
	# Function which prints a countdown to console
	# Used to retry page fetching after a certain time.	
	print("Retry #{trial}/3 in: ")
	times.downto(0) do |i|
		print "#{i} "
		sleep 1
	end		
	puts
end

def parse_mainpage(page_content, scraper)
	# This function starts on the level all of search results.
	# It iterates over eyery result. A result can be news, material or scenario
	# Each result can be identified by class '.kind-unit'
	# Every mainpage can have subpages. On a next step, subpages are parsed (if constant is true)
	
	# Result array: Each search result gets appended later
	result = []

	# 
	kind_unit = page_content.parser.css('.kind-unit')
	kind_unit.each_with_index do |item, i|
		
		# At this point we are still on the level of search result list.
		# For every result basic, informations are parsed, afterwards...
		# their underlying mainpages are parsed by url

		# ----- Initialize -----
		id = ""
		author = ""
		keywords = []
		breadcrumbs = []
		license = ""
		summary = ""
		summary_de = ""
		description = ""
		unitplan = ""
		subject = Array.new
		didactic = ""
		expertise = ""
		material = ""
		short_info = ""
		additional_info = ""
		subpage_urls = []
		subpage_arr = []

		# Add basic tags, which will be added for every scenario
		bs_tags = ["bs_AutomatedScenarios_LehrerOnline", "bs_Language_German"]

		# ----- Link to full result -----
		# Each result contains a link to the full page. Due a bug on LehrerOnline 
		# this link is not existent sometimes. If this happens abort parsing page
		title_tag = item.css('.text > a')[0]
		break if title_tag.nil? == true
		mainpage_url = title_tag.attributes['href'].value

		# ----- Get scenario title ----
		id = Digest::MD5.hexdigest(mainpage_url)

		# ----- Get scenario title ----
		title_de = title_tag.text.strip.gsub("Unterrichtseinheit: ", "")
		short_title = build_short_title(title_de)

		# ----- Premium result? -----
		# The result list contains premium content.
		# The parsing of this pages is avoided in the next step.
		premium = item.css('.colorcat-premium-bg')
		if premium.empty? == false
			$log.warn("No parsing page #{$page_position}/#{$result_counter}: It is premium content. #{short_title}")
			$page_position += 1
			next			
		end

		# ----- No Materialsammlung! ----
		# The result list contains material collections (Materialsammlung)
		# The parsing of this pages is avoided in the next step.		
		if title_de.include? "Materialsammlung"
			$log.warn("No parsing page #{$page_position}/#{$result_counter}. Its Material collection: #{short_title}")
			$page_position += 1
			next
		end

		# ----- NO DGUV!----
		# The result list contains links of www.dguv-lug.de too.
		# The parsing of this external pages is avoided in the next step.		
		if mainpage_url.include? "www.dguv-lug.de"
			$log.warn("No parsing page #{$page_position}/#{$result_counter}: It links to www.dguv-lug.de: #{short_title}")
			$page_position += 1
			next
		end

		# ----- NO Linksammlung!----
		# The result list contains link collections (Linksammlung)
		# The parsing of this pages is avoided in the next step.		
		if title_de.include? "Linksammlung"
			$log.warn("No parsing page #{$page_position}/#{$result_counter}. Its link collection: #{short_title}")
			$page_position += 1
			next
		end		

		# ----- Logging info -----
		$log.info("Parsing page #{$page_position}/#{$result_counter}: #{short_title}")
		
		# ----- Parse mainpage -----
		# Now go to the level of a single scenario/search-result, called mainpage here.
		mainpage = scraper_get_page(mainpage_url, scraper, 0, "scenario page")
		next if mainpage == nil # exclude pages not accessible
				
		# ----- Date published -----
		date = mainpage.at("meta[property='og:article:published_time']")
		date.nil? ? (date = "") : (date = date[:content])

		# ----- Author -----
		author = mainpage.at("meta[property='og:article:author']")
		author.nil? ? (author = "") : (author = author[:content])

		# ----- Tags -----
		# For parsing tags meta-keywords are used and appended to keywords array
		keywords_prop = mainpage.at("meta[property='og:article:keywords']")
		if keywords_prop.nil? == false
			keywords_prop = keywords_prop[:content].split(',')
			keywords_prop.each { |word| keywords << word.strip }
		end

		# ----- Breadcrumbs as tags -----
		# Breadcrumbs are added to tags array too.
		# Useless breadcrumbs like "Startseite" are removed.
		# Afterwards duplicate entries are removed from array
		bad_words = ["Startseite", "Unterricht"]
		crumb_list = mainpage.css('.breadcrumb > ul > li')
		if crumb_list.empty? == false
			crumb_list.each do |crumb|
				keywords << crumb.text.strip if Regexp.union(bad_words) !~ crumb
			end
		end
		keywords.uniq!

		# ----- License -----
		license = ""
		license_block = mainpage.css('.license')
		license_title = license_block.css('.license-title').text
		license_text = license_block.css('.license-text').text
		if license_block.empty? == false 
			if license_title.empty? == false
				license = license_title + ": " + license_text
			else
				license = license_text
			end
		end

		# ----- Main content -----
		# The main content is wrapped in class 'article'
		mainpage_article = mainpage.css('article')

		# ----- Summay -----
		summary_de = mainpage_article.css('.short').text.split.join(' ')

		# ----- Category list -----
		# The following code parses the blue category-list above the summary.
		# It iterates over the <li>-elements and maps the content by its class-name.
		# Problem: If a word is unknown, the content will not be parsed

		grade_level = ""
		learningtype = ""

		category_list = mainpage_article.css('.summary').css('li')
		category_list.each do |li|
			category_class = li[:class].gsub("icon-", "").gsub("icon ", "")
			category_value = li.css('span').text.split.join(' ')
	
			# Subject: If any subject of the array matches the category_class, the key will be "subject"
			words = ["bug2", "naturwissenschaften", "users4", "stats-growth", "direction", "cogs", "bubbles4", "bubble2", "aid-kit", "weltkugel", "books", "calculator3", "theater"]
			words.any? { |word| subject = category_value if category_class == word }

			# Grade and learningtype
			grade_level = category_value if category_class == "schoolstage"
			learningtype = category_value if category_class == "learningtype"
		end
		grade_level = grade_level.split(', ')
		learningtype = learningtype.split(', ')

		# Clean up subject
		if subject.empty? == false
			subject = subject.split("/")
			subject.each {|subj| subj.strip!}
		end

		# ----- Description/ Beschreibung der Unterrichtseinheit -----
		description = mainpage_article.css('.description p').text.strip

		# ----- Unitplan/ Unterrichtsablauf -----
		# Unitplan contains a list where each li-element is shown as collapsible
		# So iterate over the li, get the relevant content and format it as table
		unitplan_box = mainpage_article.search('.unitplan')
		if unitplan_box.empty? == false
			unitplan_header = unitplan_box.css('header')
			unitplan_header_plancontent = unitplan_header.css('.plancontent').text
			unitplan_header_social = unitplan_header.css('.socialform').text
			unitplan << "|=Schritt |=#{unitplan_header_plancontent} |=#{unitplan_header_social}\n"

			unitplan_list = unitplan_box.css('li')
			unitplan_list.each do |li|
				unitplan_key = li.css('h2').text.strip
				unitplan_value = li.css('.plancontent')
				unitplan_value = parse_container(unitplan_value, ["no-exclude"])
				unitplan_value = unitplan_value.gsub("\n", " \n")
				unitplan_social = li.css('.socialform').text.strip#.gsub("- ", "")
				unitplan << "|=#{unitplan_key} |#{unitplan_value} |#{unitplan_social} \n"
			end
		end

		# ----- Didactic/ Didaktisch-methodischer Kommentar -----
		# Container 'didactic' can contain paragraphs, lists (with links) or tables
		# Function 'parse_container' is made for this case
		# The container can contain links to subpages. These links are collected and parsed later.
		didactic_block = mainpage_article.css('.didactic')
		didactic = parse_container(didactic_block, ["Didaktisch-methodischer Kommentar"])
		didactic_links = didactic_block.css('a')
		subpage_urls << get_subpage_urls(didactic_links) if didactic_links.empty? == false

		# ----- Competencies/ Vermittelte Kompetenzen -----
		# Expertise will be mapped as "competencies" in json file!
		# Container 'didactic' can contain paragraphs, lists or tables
		# Function 'parse_container' is made for this case
		expertise_block = mainpage_article.search('.expertise')
		expertise = parse_container(expertise_block, ["Vermittelte Kompetenzen"])

		# ----- Material/ Links -----
		# Downloads, Links and further info are included in container called .csc-content
		# Iterate over all csc's, check for valid content, get header and content from box
		csc_content = mainpage_article.css('.csc-content')
		csc_content.each do |csc|
			next if csc.text.include?"Keine Elemente gefunden. Bitte konfigurieren"
			box_header = csc.css('header').text.strip
			material += box_header.to_title(3,1,1) if box_header.not_empty?
			link_box = csc.search('.link-box')
			material += parse_container(link_box, ["Merkliste", "Mappe"]) if link_box.empty? == false	
		end

		# ----- Short info and additional info -----
		# Kurzinformation zum Unterrichtsmaterial und zusätzliche Inhalte
		# LehrerOnline sometimes offers short information (Kurzinformation) about a scenario.
		# This short info is provided in a standard container 'csc-default' with no class attribute. 
		# To get the short info we have to identify this block by string comparison if csc_header == "Kurz...

		# Furthermore there can be more csc-defaults which contain additional info about a scenario.
		# This additional info is provided in a standard container 'csc-default' with no class attribute.
		# The rule for this container is, that it provides a header, which is not "Kurzinformation..."
		# Furthermore the container should not contain the class "link-box" which is already scraped earlier.
		# At this step the possibility of content duplicates arises. We avoid this by checking if the...
		# csc-content is already present in string 'additional_info'.

		# Furthermore there is the possibility that images are used in those containers.
		# If this case happens you can find a superior container called '.csc-textpic'.
		# So instead of using '.csc-default' we will replace it with '.csc-textpic'.
		# TODO: write explanation for the third case

		csc_default = mainpage_article.css('.csc-default')
		csc_default.each do |csc|
			csc_header = csc.css('.csc-header').text
			csc_content = csc.css('.csc-content')
			
			# If img is used you can find the container '.csc-textpic'
			csc_textpic = csc.css('.csc-textpic')
			csc_content = csc_textpic if csc_textpic.nil? == false

			link_box = csc.search('.link-box')
			if csc_header == "Kurzinformation zum Unterrichtsmaterial"
				short_info += csc_header.to_title(3,2,1)
				short_info += parse_container(csc_content, ["no_exclude"]) + "\n"
				# Find links to subpages
				links = csc_content.css('a')
				subpage_urls << get_subpage_urls(links) if links.empty? == false
				next
			elsif csc_header.empty? == false && csc_content.empty? == false && link_box.empty? == true
				additional_info_header = "\n**#{csc_header}**\n"
				additional_info_content = parse_container(csc_content, ["no_exclude"]) + "\n"
				if !additional_info.include?(additional_info_content.strip)
					additional_info += additional_info_header
					additional_info += additional_info_content
				end
				# Find links to subpages
				links = csc_content.css('a')
				subpage_urls << get_subpage_urls(links) if links.empty? == false
				next
			end

			# Csc-default can contain a more simple structure too. 
			# You will only find h2 and p. So csc itself is parsed.
			# This means a chance for content duplicates		
			csc_ignore_content = csc.text.to_s
			if csc_ignore_content.include?("Mappe") == false || csc_ignore_content.include?("Merkliste") == false || link_box.empty? == true
				csc_alternate_header = csc.css('h2').text
				csc_alternate_content = csc.css('div div p')
				if !additional_info.include?(csc_alternate_content.text.strip)
					additional_info += "\n\n**#{csc_alternate_header} (Possible duplicate)**\n" if csc_alternate_header.empty? == false
					additional_info += csc_alternate_content.text + "\n"
				end
				# Find links to subpages
				links = csc_alternate_content.css('a')
				subpage_urls << get_subpage_urls(links) if links.empty? == false
			end
		end

		# ----- Parsing subpages -----
		# Links to subpages are often found in the didactic container seen above.
		# But other containers can contain subpage-links too. That's why the links
		# are collected first and parsed at the end. So a double parsing is avoided.
		subpage_urls = subpage_urls.flatten.uniq
		subpage_urls.each { |url| subpage_arr << parse_subpage(url, scraper) } if PARSE_SUBPAGES

		# ----- Sucess counter, page position -----
		# success_counter: Incremented if page was parsed sucessfully
		# page_position: Incremented per mainpage for logging the program progress
		$success_counter += 1
		$page_position += 1

		# ----- Prettify Content -----
		# Remove leading and trailing \n \t \s from strings
		# Reduce excessive new lines (\n) to maximal two.
		unitplan = unitplan.strip.prettify_newlines
		didactic = didactic.strip.prettify_newlines
		expertise = expertise.strip.prettify_newlines
		material = material.strip.prettify_newlines
		additional_info = additional_info.strip.prettify_newlines
		#short_info = short_info.prettify_newlines #\n needed

		# Add components of scraped scenario to array which contains all scenarios
		result << {
			"id": id,
			"title": "",
			"title_de": title_de,
			"author": author,
			"subject_raw": subject,

			# Intentionally left empty - Filled by mapper later
			# Keep in sync with NavigationTagsNew!
			"subject": [],
			"affordances": [],
			"basic_function": [],
			"digital_device": [],
			"input_device": [],
			"devices": [],
			"patterns": [],
			"teaching_approach": [],
			"spatial": [],
			"information_functions": [],

			"url": mainpage_url,
			"date": date,
			"summary": summary,
			"summary_de": summary_de,
			"keywords": keywords,
			"bs_tags": bs_tags,
			"description": description,
			"breadcrumbs": breadcrumbs,
			"unitplan": unitplan,
			"didactic": didactic,
			"learningtype": learningtype,
			"grade_level": grade_level,
			"subpages": subpage_arr,
			"competencies": expertise,
			"material": material,
			"short_info": short_info,
			"additional_info": additional_info,
			"license": license
		}

	end
	return result
end

def parse_subpage(subpage_url, scraper)
	# Parsing subpages is experimental

	page = []
	scraper.get(subpage_url) do |didactic_subpage|

		# ----- Initialize -----
		subpage_content = ""
		subpage_summary_de = ""
		subpage_content = ""

		# ----- Title and summary -----
		subpage_title_de = didactic_subpage.title.strip
		summary = didactic_subpage.css('.short')
		subpage_summary_de = summary.text.split.join(' ') if summary.empty? == false

		# ----- Log info -----
		short_title = build_short_title(subpage_title_de)
		$log.info("   Parsing subpage #{short_title}")

		# ----- Article -----
		# Content is wrapped in tag 'article'. On some subpages this tag isn't present.
		# In this case it's senseless to parse content from 'csc-default'.
		article = didactic_subpage.css('article')

		# ----- Content in csc-default -----
		# Each subpage exists of many content blocks called 'csc-default'
		# We will iterate over all csc-default and find out, whats inside
		csc_default = article.children.css('.csc-default') if article.empty? == false

		if csc_default.nil? == false
			csc_default.each do |csc|
				
				# ----- Header of csc-default -----
				csc_header = csc.css('.csc-header > h2')
				subpage_content += csc_header.text.to_title(3,1,1) if csc_header.empty? == false
			
				# ----- Content of csc-default -----
				# IMPORTANT Csc-content can be a collapsible box or simple text box
				# Collapsibles are identified by class name and string comparison (first case)
				# Text box are parsed if no collapsible class name is present (second/ else case)
				csc_content = csc.css('.csc-content')			
				if csc_content.empty? == false
					classes = csc_content.attribute('class').to_s
					if classes.not_empty? && classes.include?("collapsable")
						# First Case: csc-content contains a collapsible
						# A collapsible contains header and two-columned content
						# If header is not 'zurück' add header and content to string
						header = csc_content.css('header').text
						link_box = csc.css('.link-box')
						if header != "Zurück"
							subpage_content += header.to_title(3,1,1) if header.not_empty?
							subpage_content += parse_container(link_box, ["Merkliste", "Mappe", "Vorschau"]) if link_box.empty? == false
						end
					else
						# Second Case: csc-content contains a text block
						# A text-block can consist of text, list or table
						# parse_container is made for this case
						subpage_content += parse_container(csc_content, ["no_exclude"])
					end
				end
			end
		end

		# ----- Prettify Content -----
		# Reduce excessive new lines (\n) to maximal two.
		# Remove leading and trailing \n \t \s from strings
		subpage_content = subpage_content.strip.prettify_newlines

		# Add componentes of scraped subpage to array containing all didactic subpages
		page = {"subpage_title": "", "subpage_title_de": subpage_title_de, "subpage_url": subpage_url, "subpage_summary": "", "subpage_summary_de": subpage_summary_de, "subpage_content": subpage_content}
	end
	return page
end		

def magic(keyword, scraper)
	# Define parser for specific keywords which are put in the searchform
	result = []
	scraper.get(DOMAIN) do |page|

		# Filling search form on "home" page with keyword and submit
		form = page.form_with(:class => 'searchform') { |search| search['tx_losearch_search[query]'] = keyword }
		result_page = form.submit

		# Now we are on the result page and filtering results for "Unterrichtseinheit"
		form = result_page.form_with(:name => 'loSearchForm')
		form.checkbox_with(:id => 'typearticletype-type-tx_locore_domain_model_unit').check
		result_page = form.submit

		# Get the number of search results (including news, material and scenarios)
		results_found = result_page.css('.locore-search-list header span').text.delete('^0-9').to_i

		if results_found != 0
			# How many scenarios(!!) are found in result list?
			$result_counter = result_page.at("//*[contains(text(),'Unterrichtseinheiten')]").text.to_s
			$result_counter = $result_counter.delete('^0-9')
			$log.info "Found #{$result_counter} results for keyword '#{keyword}'."

			# Parsing the whole result page
			# Note: this handles NOT a single scenario
			result << parse_mainpage(result_page, scraper)
			# A search can return many result pages.
			# If a link to the next result page exists...
			# Get this link-url, and start parsing.
			next_link = result_page.parser.css('nav.pagebrowser li.next a')
			while next_link.size > 0 do
				$log.info("Moving on to next result page.")
				next_url = next_link.attribute('href')
				navigation_page = scraper.get(next_url)
				result << parse_mainpage(navigation_page, scraper)	
				next_link = navigation_page.parser.css('nav.pagebrowser li.next a')			
			end
			#$log.info("Arrived at last result page.") if next_link.empty? == true
		else
			$log.warn("No results found for keyword #{keyword}.\n")
		end	
	end
	return result
end

def print_file(result, keyword)
	# Print data to json file
	# Param result: array containing all scenarios found for a keyword
	# Param keyword: string, the name of the keyword the search was executed.	
	keyword = keyword.gsub('ä','ae').gsub('ö','oe').gsub('ü','ue')
	keyword = keyword.gsub('Ä','Ae').gsub('Ö','Oe').gsub('Ü','Ue')
	keyword = keyword.gsub('ß','ss')
	keyword = keyword.gsub(/[^0-9A-Za-z ]/, '')
	filename = "#{keyword}-lehreronline-#{$success_counter}.json"
	File.open(filename, "w") do |f|
		f.write ('{"source":"LehrerOnline", "domain": "www.lehrer-online.de", "language": "de", "scenarios":')
		f.write(result.to_json)
		f.write ("}")
	end
	$log.info("#{$success_counter-1}/#{$result_counter} mainpages wrote to \"#{filename}\"\n")
end

# ---- Main program ----

# Logger settings
$log = Logger.new(STDOUT)
$log.formatter = proc { |type, date, prog, msg| "#{type} --: #{msg}\n" }

$log.info("Starting program")

# Initialize new Mechanize object, bypass SSL verification
# Limit scraping to once every half-second to avoid IP banning.
scraper = Mechanize.new { |agent| agent.user_agent_alias = 'Windows Chrome' }
scraper.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE 
scraper.history_added = Proc.new { sleep 0.5 }

# Check constant: keywords
if (defined?(KEYWORDS)).nil? == true
	$log.fatal("No keywords found. Enter keyword in .rb file")
	exit
end

# Check constant: Domain
if (defined?(DOMAIN)).nil? == true
	$log.fatal("Domain not found. Enter domain in .rb file")
	exit
end

KEYWORDS.each do |keyword|
	# For each keyword count successful mainpage-scraping
	$success_counter = 1
	$page_position = 1
	# 'Magic' fills search form and sends result-pages to parser
	# Variable 'result' is an array, where each element contains the content of one search-site.
	# So flattening the array is necessary
	result = magic(keyword, scraper)
	result = result.flatten
	print_file(result, keyword) if result.length > 0
end

$log.info("All keywords done!")
$log.info("Don't forget to translate scenarios with translate.rb.")