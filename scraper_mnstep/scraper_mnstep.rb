# ---- Program info ----
# The 'scraper_mnstep' uses webscraping technologies to fetch teaching activities of the 'MnSTEP Teaching Activity Collection'.
# "The [MnSTEP] activities reflect individual integration plans for applying newfound content knowledge and inquiry strategies directly in classroom curriculum and practice". 
# Source: https://serc.carleton.edu/sp/mnstep/ 

# The 'scraper_mnstep' program opens http://serc.carleton.edu/sp/mnstep/activities.html and uses the search form to find the terms defined below (See KEYWORDS)
# Then it fetches the results/activities returned by the search. There it analyzes the content of each activity and will save it in appropriate fields in a .json file. 
# The resulting .json files are structured in a way the 'xwiki_uploader' can read and upload the data to the eSIT4SIP-XWiki.
# Media elements such as e.g. jpg or text files are not downloaded.

# IMPORTANT
# This software only downloads activities (called scenarios here too) with a free-license. 
# In MnSTEP the activities are provided with this text: 
# "Material on this page is offered under a Creative Commons license unless otherwise noted below."
# The scraper checks this text and does not download activities with another license.
# We guarantee that we maintain the license of the activities.

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
require 'json'
require 'logger'
require 'rubygems'

require 'mechanize'
require 'nokogiri'

# The url where the scraper will find the search form
DOMAIN = 'http://serc.carleton.edu/sp/mnstep/activities.html'

# ---- Keyword definition ----
# For each keyword in the array, the program will execute a search and fetch the resulting activities.
# You can line multiple strings in the array. Each term will result in a extra .json file named by it.
KEYWORDS = ["computer", "online", "internet", "media"]

# ---- Keywords for testing purposes ----
#KEYWORDS = ["Reading Poetry "] #4
#KEYWORDS = ["Digital learning"]
#KEYWORDS = ["Computer based learning Bottle Rocket outdoor"] # 2
#KEYWORDS = ["Geology of the Grand Canyon: Interpreting its rock layers and formation"] #2
#KEYWORDS = ["Exploring Sugarloaf Cove Investigating the Geology of Lake Superior's North Shore"] #1
#KEYWORDS = ["Understanding Half–Life Simulating the process of a radioactive material decaying according to the concept of a half-life"] #1
#KEYWORDS = ["Reciprocal: Index to Identify Water"] #7
#KEYWORDS = ["flame test"] #7
#KEYWORDS = ["spring two"] #34
#KEYWORDS = ["Electrical Circuits closed"] #12
#KEYWORDS = ["Air- She's so heavy"] #4#KEYWORDS = ["air"] #103

# ---- Check functions for finding hidden lists ----
#KEYWORDS = ["Best Edible Model of a Cell Contest"] #1 check recursive list
#KEYWORDS = ["Decomposition Community"] #1 check excessive newlines
#KEYWORDS = ["This activity lends itself well to the review and repetition of previous topics and skills."] #1 test *
#KEYWORDS = ["Decomposition Community"] #1 test -
#KEYWORDS = ["synclines anticlines"] #1 test -
#KEYWORDS = ["Best Edible Model of a Cell Contest"] #1 test 1. 2. 3.
#KEYWORDS = ["Newtonian Forces Plate Tectonics"] #2 test 1. 2. 3.
#KEYWORDS = ["respecto a la retencion de agua"] #1 test A. B. C.
#KEYWORDS = ["Minnesota con respecto"] #1 test roman numbers like II

# ---- Expand Ruby Class 'String' ----
class String
	# Adding methods to string-class for method chaining
	# Mainly methods for styling content with XWiki markup.

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

	def prettify(max_newlines)
		# remove tabulator
		# reduce two ore more spaces to only one
		# change underscores so xwiki won't underline
		# remove spaces between newlines for next step
		# reduce exceeded newlines to a given number
		# return prettified text
		text = self.gsub("\t", ' ')
		text = text.gsub(/ {2,}/, ' ')
		5.times { |i| text.gsub!("__", "_ _") }
		5.times { |i| text.gsub!("\n \n", "\n\n") }

		replace_with = "\n"*max_newlines
		20.downto(max_newlines+1) do |i|
			replace = "\n"*i
			text = text.gsub(replace, replace_with)
		end
		return text
	end

	def to_title(type, before, after) 
		# Builds title1, title2... and adds newlines.
		title = "=" * type + " " + self + " " + "=" * type 
		title = title.newline(before, after)
	end
end

# ---- Monkey Patch 'Roman Monkey' ----
# "Code to monkey patch Integer with to_roman and to_arabic_number  methods to convert numbers to Roman
# numerals and vice-versa. Monkey patching is not necessarily the best approch but it is the most fun."
# Source: https://github.com/MrPowers/roman_monkey 

class Integer

	# recursive
	def to_roman(number = self, result = "")
		return result if number == 0
		roman_mapping.keys.each do |divisor|
			quotient, modulus = number.divmod(divisor)
			result << roman_mapping[divisor] * quotient
			return to_roman(modulus, result) if quotient > 0
		end
	end

	# iterative
	def to_roman
		result = ""
		number = self
		roman_mapping.keys.each do |divisor|
		  quotient, modulus = number.divmod(divisor)
		  result << roman_mapping[divisor] * quotient
		  number = modulus
		end
		result
	end

	private

	def roman_mapping
		{
			1000 => "M",
			900 => "CM",
			500 => "D",
			400 => "CD",
			100 => "C",
			90 => "XC",
			50 => "L",
			40 => "XL",
			10 => "X",
			9 => "IX",
			5 => "V",
			4 => "IV",
			1 => "I"
		}
	end
end

def get_text_list_or_table(content_block, strings_to_exclude)
	# Helper function which returns headlines, text, links, lists and tables correctly formatted as string.
	# It iterates over all nodes of a given container (param content_block) and formats content apporpriate
	# to its element name. This function can be e.g. used, when a content block can't be identified by class
	# name exactly. Furthermore there are headlines which should not be scraped. Parameter 'strings_to_exclude'.
	# was made for that. Param strings_to_exclude contains comma seperated words which are splitted to array.

	# Variable 'real_list_found' will be true if a <ul> or <ol> node was found. After this function the returned...
	# content is scanned with function 'find_hidden_lists', which replaces 1. 2. 3. with Xwiki markup, which...
	# makes a recursive parsed list obsolete. If 'real_list_found' is true 'find_hidden_lists' won't be called.
	real_list_found = false

	content = ""
	content_block.children.each do |node|
		node_name = node.name.to_s
		node_text = node.text.strip.to_s

		# There are some reasons to skip a node
		# - Skip node if it doesn't contain any text
		# - Skip node if a string_to_exclude matches node_text
		# - Skip node if it contains a buggy comment (LehrerOnline specific)
		skip = false
		#skip = true if node_text.empty? == true # needed in mnstep
		strings_to_exclude.any? { |word| skip = true if node_text == word }
		skip = true if node_text =~ /f:render(.*?)Array/
		next if skip

		if node_name == "div"
			keep, ignore = get_text_list_or_table(node, strings_to_exclude)
			content += keep
		elsif node_name == "h1" || node_name == "h2" || node_name == "h3"
			content += parse_headline(node).to_title(3,1,1)
		elsif node_name == "br"
			content += "\n"
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
			real_list_found = true
			content += "\n"
			content += parse_list(node, "ul", strings_to_exclude, 1)
			content += "\n"
		elsif node_name == "ol"
			real_list_found = true
			content += "\n"
			content += parse_list(node, "ol", strings_to_exclude, 1)
			content += "\n"
		elsif node_name == "table"
			content += parse_table(node)
		elsif node_name == "sub"
			content += parse_sub(node)
		elsif node_name == "sup"
			content += parse_sup(node)
		elsif node_name == "blockquote"
			content += parse_blockquote(node)			
		else
			content += node.text.split.join(' ')
		end		
	end
	# Add newline for better list identification
	content += "\n"
	return content, real_list_found
end

def parse_table(node)
	# Helper function called by 'get_text_list_or_table' which returns tables correctly formatted as string.
	# This function is called when 'get_text_list..' identifies a table. Incoming parameter is <table> node.
	# It iterates over all rows & gets all table cells. Afterwards it iterates over all cells and identifies
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
	# Helper function called by 'get_text_list_or_table' which returns lists correctly formatted as string.
	# This function is called when 'get_text_list..' identifies a <ul> or <ol> node. Incoming parameters are 
	# <ul> or <ol> as list_node. The list-type is given as string in 'ul_or_ol'. This parameter determines how the list
	# is formatted. Furthermore there is paramter 'strings_to_exclude' which helps to ignore some elements by their text.
	# This function gets all <li>-elements from the list-node and iterates over them. Each <li>-element can contain
	# multiple children (p, text, ul...). So each li-children gets formatted by its node-name and helper functions.
	# This function works recursive since each list-element can contain further lists. The parameter 'level' was made
	# to handle the correct markup formatting of nested lists.

	content = "\n"
	last_content = "zzzz"
	ul_or_ol == "ul" ? (character = "*" * level + " ") : (character = "1" * level + ". ")

	# Get all list elements
	list = list_node.css('li')
	list.each do |li|
		# For each list-element do
		# - Get all child nodes of <li> like div, text, h1, p, a ...
		# - Reset variable 'li_content' for collecting node content
		li_children = li.children
		li_content = ""

		if li_children.empty? == false
			li_children.each do |node|
				# For each <li> child nodes do
				# - Skip a node if condition is true (see below)
				# - Collect node content in variable 'li_content'
				node_name = node.name.to_s
				node_text = node.text.strip.to_s

				# There are some reasons to skip a node
				# - Skip node if it doesn't contain any text
				# - Skip node if a string_to_exclude matches node_text
				# - Skip node if it contains a buggy comment
				# - Skip node if node_text is the same as previous content
				skip = false
				#skip = true if node_text.empty? == true
				strings_to_exclude.any? { |word| skip = true if node_text == word }
				skip = true if node_text =~ /f:render(.*?)Array/
				skip = true if node_text == last_content
				next if skip
				
				if node_name == "div"
					keep, ignore = get_text_list_or_table(node, strings_to_exclude)
					li_content += keep
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
	return ",,#{node.text.strip},,"
end

def parse_sup(node)
	return "^^,,#{node.text.strip},,^^"
end

def parse_text(node, type)
	text = node.text.strip
	text = "" if text.empty? == true

	name_next = node.next
	# If link is next element, stay inline
	if name_next.nil? == false && name_next.name == "a"
		text += " "
	else
		# If no link is next element and no list element
		#text += "\n" if type == "normal"
	end
	return text
end

def parse_paragraph(node, type)
	# A paragraph can have children too: text, a, b, span...
	# If p has children send node to get_text_list_or_table.
	# If p has no children simply read its text.

	content = ""
	children = node.children
	if children.empty? == false
		content, ignore = get_text_list_or_table(node, ["no-exclude"])
	else
		content = parse_text(node, type)
	end
	content += "\n\n"
	return content
end

def parse_blockquote(node)
	# In the web blockqoutes normally are indented to the right.
	# On Esit4sip blockqotes are not used. So only the inside text is parsed.

	content = ""
	children = node.children
	if children.empty? == false
		content, ignore = get_text_list_or_table(node, ["no-exclude"])
	else
		content = parse_text(node, type)
	end
	#content += "\n\n"
	return content	

end

def parse_strong(node)
	# Helper function parses <strong> and <b> nodes. 
	# On Mnstep some lists number-bullets are strong which destroys the list.
	# So this function ignores bold text which contains digits/numbers.

	content = ""
	node_text = node.text.strip.capitalize

	# If node_text doen't contain digits then format it with XWiki markup.
	# If it contains a digit it can be a list point. Markup would destroy the list.
	if node_text.not_empty?
		if node_text =~ /^\D*$/ 
			# Doesn't contain a digit
			content = "**#{node_text}**"
			# Some strongs are used as headlines. 
			# This case can be identified if the following node is a <br> or <p>
			# To prove that we have to look for the second-next node.
			next_node = node.next
			if next_node.nil? == false
				next_name = next_node.name
				if next_name.to_s == "text"
					next_node = next_node.next
					if next_node.nil? == false
						next_name = next_node.name.to_s
						content = "\n\n" + content + "\n\n" if next_name == "br"
						content = "\n\n" + content + "\n\n" if next_name == "p"
					end
				end
			end			
		else 
			# Contains a digit
			content = node_text
		end
	end


	return content
end


def parse_link(link)
	# Function parses hyperlinks and formats it correctly.
	# It uses the link-text and the url to build markup.

	content = ""
	link_text = link.text.strip
	link_url = link.attribute('href').to_s

	if link_text.empty? == false && link_url.empty? == false
		content += "[[#{link_text}>>url:#{link_url}]]"
	end
	return content
end

def build_short_title(title)
	# Some page titles are too long to generate meaningful log info. 
	# So this function trims a given title to x characters. 	
	title.length >= 40 ? (short_title = "#{title[0..40]}...") : (short_title = title)
end

def find_hidden_lists(text)

	#DEPRECATED

	# Mnstep often uses text hyphens or numbers for lists instead of html markup.
	# This function identifies numbered and unordered lists in a given text.
	
	# If 1. and 2. appears in a text you can expect, that there is a numbered list.
	# Replace all 1. 2. 3. 4.... by '1.' (xwiki markup).
	if text.include?("1. ") && text.include?("2. ")
		1.upto(50) { |n| text.gsub!("#{n}. ", "1.") }
	end
	if text.include?("1.") && text.include?("2.") 
		1.upto(50) { |n| text.gsub!("#{n}.", "1.") }
	end

	# If (1) and (2) appears in a text you can expect, that there is a numbered list.
	# Replace all (1) (2) (3) (4)... by '1.' (xwiki markup).
	if text.include?("(1) ") && text.include?("(2) ")
		1.upto(50) { |n| text.gsub!("(#{n}) ", "1.") }
		1.upto(50) { |n| text.gsub!("(#{n})", "1.") }
	end
	if text.include?("(1)") && text.include?("(2)")
		1.upto(50) { |n| text.gsub!("#({n}) ", "1.") }
		1.upto(50) { |n| text.gsub!("#({n})", "1.") }
	end

	# If 1) and 2) appears in a text you can expect, that there is a numbered list.
	# Replace all 1) 2) 3) 4)... by '1.' (xwiki markup).
	if text.include?("1) ") && text.include?("2) ")
		1.upto(50) { |n| text.gsub!("#{n}) ", "1.") }
		1.upto(50) { |n| text.gsub!("#{n})", "1.") }
	end
	if text.include?("1)") && text.include?("2)")
		1.upto(50) { |n| text.gsub!("#{n}) ", "1.") }
		1.upto(50) { |n| text.gsub!("#{n})", "1.") }
	end

	# XWiki needs the markup: '1. ' so spaces are added here.
	if text.scan("1.").length >= 2
		text.gsub!("1.", "1. ")
	end	

	# Sometimes the lists on xwiki only contains of 1. 1. 1...
	# Xwiki starts a new list because there are too many \n instead of one.
	# Here a regex is used to identify this sequence: 1. some random text \n+
	# Afterwards each result is replaced with itself but without any \n
	# In a next step newlines are added before each '1.'
	results = text.scan(/1\.\s.+\n+/)
	results.each do |result|
		if text.include?(result)
			replace_with = result.split.join(' ')
			text.gsub!(result, replace_with)
		end
	end
	text.gsub!("1.", "\n 1.")

=begin
	results_length = results.length
	results.each_with_index do |result, i|
		if text.include?(result)
			replace_with = result.prettify(1)
			replace_with = "\n" + replace_with if i == 0
			replace_with = replace_with + "\n" if i == results_length -1
			text.gsub!(result, replace_with)
		end
	end
=end

	# An unordered list can be identified by a hyphen followd by a tabulator.
	# There are more options to identfy lists with regex: - some_characters \n 
	text.gsub!("-\t", "* ")

	# The bad thing about reducing newlines to max. one, is that headlines are destroyed.
	# Mnstep uses simple bold headlines which should be like "\n\n **text **".
	# With the next regex these newlines are restored.
	results = text.scan(/\*\*\w+/)
	results.each do |result|
		text.gsub!(result, "\n\n #{result}")
	end

	return text
end

def find_hidden_ul(text)

	# Find * and - lists with regular expression: *randomtext\n (1 or more newlines)
	# If three or more results are found, for each result do:
	# - Variable 'replace_with' contains correctly formatted text with only one newline: * randomtext\n
	# - Add newlines if result (list element) is at beggining or end of array (list).
	# - Use the old result to find the position in the given text and replace it with 'replace_with'

	# * list
	results = text.scan(/\*.+\n+/)
	if results.length >= 3
		results.each_with_index do |result, i|
			# Ignore result if there's a **bold** text at it's beginning
			# Find all bold headlines and put their positions into array.
			# If a bold headline appears at position 0 the result is ignored.
			positions = result.enum_for(:scan, /\*\*.+\*\*/).map { Regexp.last_match.begin(0) }
			next if positions.include?(0)

			replace_with = result.sub("*", "* ").prettify(1)
			replace_with = "\n" + replace_with if i == 0 # start of list
			replace_with += "\n \n" if i == results.length - 1	# end of list
			text = text.sub(result, replace_with) # replace old list element with new
		end
	end

	# - list
	if text.include?("1.") && text.include?("2.")
		results = text.scan(/\-\s?[A-Z1-9].{1,700}\n+/)
		if results.length >= 3
			results.each_with_index do |result, i|
				replace_with = result.sub("- ", "* ").prettify(2)
				replace_with = replace_with.sub("-", "* ").prettify(2)
				replace_with = "\n" + replace_with if i == 0 # start of list
				replace_with += "\n \n" if i == results.length - 1	# end of list
				text = text.sub(result, replace_with) # replace old list element with new
			end
		end
	end		
	return text
end

def find_hidden_ol(text)

	# This function identifies numbered and unordered lists in a given text.
	# If 1. and 2. ... appears in a text you can expect, that there is a numbered list.

	# Replace 1. and 1.\s
	results = text.scan(/\d\d?\..+\n/)
	if results.length >= 3
		results.each_with_index do |result, i|
			replace_with = result.sub(/\d\d?\.\s?/, "1. ").prettify(1)
			replace_with = "\n" + replace_with if i == 0 # start of list
			replace_with += "\n \n" if i == results.length - 1	# end of list
			text = text.sub(result, replace_with) # replace old list element with new
		end
	end

	# Replace (1) and (1)\s
	# Not necessary due too less hits and inline use of the numbers
	#results = text.scan(/\(\d\d?\).+\n/)
	#if results.length >= 3
		#results.each_with_index do |result, i|
			#replace_with = result.prettify(0)
			#replace_with = replace_with.sub(/\(\d\d?\)/, "\n1. ")
			#replace_with = "\n" + replace_with if i == 0 # start of list
			#replace_with += "\n \n" if i == results.length - 1	# end of list
			#text = text.sub(result, replace_with) # replace old list element with new
		#end
	#end
	return text
end

def find_hidden_letter_list(text)	
	
	# Replace A. and A.\s
	list_style = "(\% style='list-style-type: upper-alpha' %)\n"
	results = text.scan(/[A-Z]\.\s.+\n+/)
	if results.length >= 3
		results.each_with_index do |result, i|
			replace_with = result.gsub(/[A-Z]\.\s/, "* ").prettify(1)
			replace_with = result.gsub(/[A-Z]\./, "* ").prettify(1)
			replace_with = list_style + replace_with # add style information
			replace_with = "\n" + replace_with if i == 0 # start of list
			replace_with = replace_with.strip + "\n \n" if i == results.length - 1	# end of list
			text = text.sub(result, replace_with) # replace old list element with new
		end
	end
	return text
end

def find_hidden_roman_list(text)

	# Replace roman numbers up to 39: XXXIX
	list_style = "(\% style='list-style-type: upper-roman' %)\n"
	results = text.scan(/[IVX]{1,3}\.\s.+\n/)
	if results.length >= 2
		results.each_with_index do |result, i|
			replace_with = result.prettify(0)
			roman = (i+1).to_roman + ". "
			replace_with = replace_with.gsub(roman, "* ")
			roman = (i+1).to_roman + "."
			replace_with = replace_with.gsub(roman, "* ")
			replace_with = list_style + replace_with # add style information
			replace_with = "\n" + replace_with if i == 0 # start of list
			replace_with += "\n \n" if i == results.length - 1	# end of list
			text = text.sub(result, replace_with) # replace old list element with new
		end
	end
	return text
end

def parse_result_page(page_content, scraper)
	# This function starts on the level all of search results.
	# It iterates over eyery scenario-result.
	# Each result can be identified by class '.searchhitdiv'
	
	# Result array: Each search result gets appended later
	result = []

	# How many results are found?
	results_found = page_content.css('.searchtrivia strong').text.delete('^0-9').to_i

	# Cariable 'searchhitdiv' contains a list of search results.
	# Every searchhitdiv represents one search result.
	searchhitdiv = page_content.parser.css('.searchhitdiv')
	searchhitdiv.each_with_index do |item, i|

		# At this point we are still on the level of search results.
		# For every result basic informations are parsed, afterwards...
		# their underlying mainpages are parsed by url

		# ----- Initialize variables -----
		author = ""
		summary = ""
		content = []		
		category_hash = Hash.new
		subject = ""
		spatial_settings = ""
		special_interest = ""
		grade_level = ""
		theme = ""
		date = ""
		date_modified = ""
		license = ""
		content_tags = []
		learning_goals = ""
		context_for_use = ""
		description_and_teaching_materials = ""
		teaching_notes_and_tips = ""
		assessment = ""
		references_and_resources = ""
		#standards = # not parsed
		
		# Add basic tags, which will be added for every scenario
		bs_tags = ["bs_AutomatedScenarios_MnSTEP", "bs_Language_English"]

		# ----- Title ----
		title_tag = item.search('.searchhit > a')[0]
		title = title_tag.text.strip

		# ----- URL ----
		url = title_tag.attributes['href'].value
		
		# ----- Logging info -----
		short_title = build_short_title(title)
		$log.info("Parsing page #{$success_counter}/#{results_found}: #{short_title}")

		# ----- Parse scenario mainpage -----
		# Now go to the level of a single scenario/search-result, called mainpage here.
		mainpage = scraper.get(url)

		# ----- Date created / modified -----
		date = mainpage.at("head meta[name='datecreated']")[:content]
		date_modified = mainpage.at("head meta[name='datemodified']")[:content]
		date = Date.strptime(date, "%Y%m%d").strftime("%d.%m.%Y")
		date_modified = Date.strptime(date_modified, "%Y%m%d").strftime("%d.%m.%Y")

		# ----- Tags -----
		# Get Tags from meta, split them by comma and do some cosmetics
		tag_str = mainpage.at("head meta[name='keywords']")[:content]
		if tag_str.empty? == false
			tag_str = tag_str.gsub(" :",":").gsub(": ",":").gsub(":",": ")
			tag_str = tag_str.gsub(" ,",",").gsub(/\s+/,' ') 
			tag_arr = tag_str.split(/,/)
		
			# If remove_word doesn't appear in tag: add tag to string
			remove_words = ["MnSTEP", "Mini-Colection", "Mini-Collection"]
			tag_arr = tag_arr.uniq
			tag_arr.each do |tag|
				if remove_words.any? { |word| tag.include?(word) } == false
					content_tags << tag.strip if tag.length > 1
				end
			end
		end
		content_tags = content_tags.uniq

		# ----- Main content -----
		# The main content is wrapped in id 'content'			
		mainpage_content = mainpage.css('#content')
			
		# ----- Author -----
		author = mainpage_content.css('.author > div').text.split.join(' ')

		# ----- Summary -----
		summary = mainpage_content.css('.descriptionpullquote div > p').text.strip

		# ----- Content Boxes -----
		# There are content boxes like "Learning Goals", "Context for Use"...
		# Each box can be identified by its pre-defined h2 headline. 
		# For each headline, get the following <div> which contains the content.
		# Parse this content with get_text_list_or_table 
		# Find_hidden_lists if get_text_list_or_table did not find <ul> or <ol> nodes.

		headlines = mainpage_content.css('h2')
		headlines.each do |headline|
			box = headline.next_element
			box_content, real_list_found = get_text_list_or_table(box, ["no-exclude"])
			#box_content = find_hidden_lists(box_content) if real_list_found == false # deprecated

			box_content = box_content.prettify(3)
			box_content = find_hidden_ul(box_content) if real_list_found == false
			box_content = find_hidden_ol(box_content) if real_list_found == false
			#box_content = find_hidden_roman_list(box_content) if real_list_found == false
			#box_content = find_hidden_letter_list(box_content) if real_list_found == false
			headline = headline.text.strip.downcase

			if headline == "learning goals"
				learning_goals = box_content
			elsif headline == "context for use"
				context_for_use = box_content
			elsif headline == "description and teaching materials"
				description_and_teaching_materials = box_content
			elsif headline == "teaching notes and tips"
				teaching_notes_and_tips = box_content
			elsif headline == "assessment"
				assessment = box_content
			elsif headline == "references and resources"
				references_and_resources = box_content
			elsif headline == "standards"
				#standards = box_content # ignored
			else
				$log.warn("-- Unknown headline of content box appeared: #{headline}")
			end
		end

		# ----- Categories -----
		# The "Context of use" contains categories like subject, resource type... wrapped by class 'mediumsmall'.
		# To scrape the categories iterate over all child-nodes of mediumsmall and add the content to hash.
		# Each category owns a headline which is wrapped in <strong> tag. So if this tag appears, it is used as hash key

		category_hash = { subject: "", spatial_settings: "", special_interest: "", grade_level: "", theme: "", resource_type: "" }

		prev_head = ""
		mediumsmall = mainpage_content.css('.mediumsmall')
		mediumsmall.children.each do |node|
			node_name = node.name.to_s
			node_text = node.text.strip
			if node_name == "strong"
				prev_head = node_text.downcase.gsub(" ", "_")
				category_hash[prev_head] = ""
			elsif node_name == "br" || node_text.empty?
				# do nothing				
			else
				category_hash[prev_head] << node.text
			end
		end

		category_hash.each do |key, value|
			value.sub!(":","") if value.start_with?(":")
			value = value.strip
			# Mapping to variables
			subject = value if key == "subject"
			spatial_settings = value if key == "resource_type"
			special_interest = value if key == "special_interest"
			grade_level = value if key == "grade_level"
			theme = value if key == "theme"
		end

		# ----- License -----
		footer = mainpage.search('#footer')
		license = footer.css('.mediumsmall > p').first.text.split.join(' ')
		reuse_text = footer.css('#page_reuse_text').text.split.join(' ')
		if reuse_text == "Page Text A standard license applies as described above. Click More Information below."
			license.gsub!(" unless otherwise noted below", "")
			# Is incremented if page was parsed sucessfully
			$success_counter += 1
		else
			#license = license + "\n" + reuse_text
			$log.warn("Activity is ignored due to mismatch in license.\n")
			next
		end

		# ----- Prettify Content -----
		# Reduce excessive new lines (\n) to maximal two.
		# Remove leading and trailing \n \t \s from strings
		learning_goals = learning_goals.strip.prettify(2)
		context_for_use = context_for_use.strip.prettify(2)
		description_and_teaching_materials = description_and_teaching_materials.strip.prettify(2)
		teaching_notes_and_tips = teaching_notes_and_tips.strip.prettify(2)
		assessment = assessment.strip.prettify(2)
		references_and_resources = references_and_resources.strip.prettify(2)

		# Current scenario gets appended to result-array which contains many scenarios
		result << {
			"title": title,
			"author": author,
			"subject": "",
			"subject_raw": subject,
			"grade_level": grade_level,
			"spatial_settings": spatial_settings,
			"special_interest": special_interest,
			"theme": theme,
			"url": url,
			"date": date,
			"date_modified": date_modified,
			"summary": summary,
			"content_tags": content_tags,
			"bs_tags": bs_tags,
			#"categories": category_hash,
			"learning_goals": learning_goals,
			"context_for_use": context_for_use,
			"description_and_teaching_materials": description_and_teaching_materials,
			"teaching_notes_and_tips": teaching_notes_and_tips,
			"assessment": assessment,
			"references_and_resources": references_and_resources,
			"license": license
		}

	end
	return result
end

def magic(keyword, scraper)
	# Define parser for specific keywords which are put in the searchform
	# Param keyword: string, a term used to search with search form
	# Param scraper: Mechanize object

	result = []
	
	scraper.get(DOMAIN) do |page|

		# Fill in the search form
		form = page.form_with(:class => 'facetedsearch') { |search| search['search_text'] = keyword }
		# Submit the search form and save the returning result page
		result_page = form.submit

		# Get the number of search results
		results_found = result_page.css('.searchtrivia strong').text.delete('^0-9').to_i

		if results_found != 0
			$log.info "Found #{results_found} results for keyword '#{keyword}'."
			# Parsing the whole result page
			result << parse_result_page(result_page, scraper)
			# A search can return many result pages.
			# If a link to the next result page exists...
			# Get this link-url, and start parsing.
			next_url = ""
			next_links = result_page.parser.css('.searchnextprev > a')
			next_links.each { |link| next_url = link.attribute('href').to_s if link.text.include?"Next" }

			while next_url.length > 1
				$log.info("Moving on to next result page.")
				new_page = scraper.get(next_url)
				result << parse_result_page(new_page, scraper)
				next_url = ""
				next_links = new_page.parser.css('.searchnextprev > a')
				next_links.each { |link| next_url = link.attribute('href').to_s if link.text.include?"Next" }
			end
			$log.info("Arrived at last result page.") if next_url.empty? == true
		else
			$log.warn("No results found for keyword #{keyword}.\n")
		end
	end
	return result
end

# Print information to json file
def print_file(result, keyword)
	# Param result: array containing all scenarios found for a keyword
	# Param keyword: string, the name of the keyword the search was executed.
	keyword = keyword.gsub('ä','ae').gsub('ö','oe').gsub('ü','ue')
	keyword = keyword.gsub('Ä','Ae').gsub('Ö','Oe').gsub('Ü','Ue')
	keyword = keyword.gsub(/[^0-9A-Za-z ]/, '')
	filename = "#{keyword}.json"
	File.open(filename, "w") do |f|
		f.write ('{"source":"MnSTEP", "domain": "http://serc.carleton.edu/sp/mnstep/index.html", "language": "en", "scenarios":')
		f.write(result.to_json)
		f.write ('}')
	end
	$log.info("#{$success_counter-1} pages wrote to \"#{filename}\"")
end

# ---- Main program ----

# Logger settings
$log = Logger.new(STDOUT)
$log.formatter = proc { |type, date, prog, msg| "#{type} --: #{msg}\n" }

# Initialize new Mechanize object, bypass SSL verification
# Limit scraping to once every half-second to avoid IP banning.
scraper = Mechanize.new { |agent| agent.user_agent_alias = 'Windows Chrome' }
scraper.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE 
scraper.history_added = Proc.new { sleep 0.5 }

# Check keywords
if (defined?(KEYWORDS)).nil? == true
	$log.fatal("No keywords found. Enter keyword in .rb file")
	exit
end

# Check Domain
if (defined?(DOMAIN)).nil? == true
	$log.fatal("Domain not found. Enter domain in .rb file")
	exit
end

KEYWORDS.each do |keyword|
	# For each keyword count successful mainpage-scraping
	$success_counter = 1
	# 'Magic' fills search form and sends result-pages to parser
	result = magic(keyword, scraper)
	# result[0] contains scenarios of the first search-results-site
	# result[1] contains scenarios of the next  search-results-site
	# So flattening the array at the end is necessary
	result = result.flatten
	print_file(result, keyword) if result.length > 0
end

$log.info("All keywords done!")