# ---- Program info ----
# The main language of the scenarios written in the eSIT4SIP project is English.
# The scenarios presented by Lehrer-Online are written in German. 
# So we decided to provide at least an englisch title and abstract.
# 'translate_scenarios' translates user-defined fields into a user-defined language
# The program uses https://translate.yandex.net API to translate the content
# Translation requests are made over HTTP Post with Typhoeus gem.
# The program will output a .json file with suffix 'previousFilename-translated'.

# IMPORTANT
# If you use the yandex translation service you have to generate your own API key.
# Furthermore you must comply with their license terms. For example you have to
# add the text "Powered by Yandex.Translate". This is not done by this program!
# In case of eSIT4SIP this is done by the 'xwiki_uploader'.
# See https://tech.yandex.com/translate/doc/dg/concepts/design-requirements-docpage/

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


require 'cgi'
require 'find'
require 'json'
require 'logger'
require 'optparse'

require 'highline/import'
require 'typhoeus'

# Fields to translate: Choose the source and target field
# Note: both files have to be existent in the .json file
# That means that the program does not generate a new field if it is not existent yet
MAINPAGE_TRANSLATE_FIELDS = { "title_de" => "title", "summary_de" => "summary" }
# Subpage translation is experimental, since subpage parsing in webscraper is experimental too
SUBPAGE_TRANSLATE_FIELDS = { "subpage_title_de" => "subpage_title", "subpage_summary_de" => "subpage_summary" }

# Some scraper versions don't scrape subpages
# The current version of 'scraper_lehreronline' doesn't scrape subpages
# If no subpages are present, set TRANSLATE_SUBPAGES to false.
TRANSLATE_SUBPAGES = false

# If you use the yandex translation service you have to generate your own API key.
YANDEX_KEY = ""

# Logger settings
$log = Logger.new(STDOUT)
$log.formatter = proc { |type, date, prog, msg| "#{type} --: #{msg}\n" }

# OptionParser
$options = {}
OptionParser.new do |opt|
	opt.on('-r', '--target_field_okay') { |o| $options[:target_field_okay] = "y" }
	opt.on('-s', '--source_lang') { |o| options[:source_lang] = o }
	opt.on('-t', '--target_lang') { |o| options[:target_lang] = o }
end.parse!

def list_files

	# Check for json files
	files = Dir.glob("*.json")
	if files.empty? 
		$log.error("No json files found in current directory. Add files and restart program.")
		exit
	end

	# List file names
	puts "\nFound #{files.length} files for translation."
	files.each_with_index { |file, i| puts i.to_s+ ": " + file }

	# User must choose files with only numbers and ,
	puts "Use numbers to choose files. Multiple files can be seperated by ',' " 
	chosen = gets.chomp
	loop do 
	  break if chosen =~ /^-?[0-9,]+$/
	  puts "Invalid input. Use numbers to choose files. Seperate with ','."
	  chosen = gets.chomp
	end 

	filenames = Array.new()
	chosen = chosen.split(/\s*,\s*/)
	chosen = chosen.uniq
	chosen.each do |num|
		filenames << files[num.to_i] if num.to_i <= files.length
	end
	return filenames
end

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

def build_short_title(title)
	title.length >= 40 ? (short_title = "#{title[0..40]}...") : (short_title = title)
end

def parse_json(filename)
	begin
		file = File.read(filename, :encoding => 'UTF-8')
		data = JSON.parse(file)
		$log.info("Success: Parsing '#{filename}' was sucessful")
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

def write_json(data, filename, success_counter, page_counter)
	if success_counter >= 1
		filename = filename.sub(".json", "-translated.json") if filename !~ /translated/
		File.write(filename, data.to_json)
		$log.info("#{success_counter}/#{page_counter} pages translated and wrote to \"#{filename}\"")
		puts
	else
		$log.warn("#{success_counter}/#{page_counter} pages translated. See log above.")
		puts
	end
end

def check_language_combination(data, source_lang)
	# User can choose multiple files. It is possible that a file 
	# doesn't contain the source language, which was entered by user
	language_matching = true
	if data['language'] != source_lang
		$log.fatal("Choosen source language (#{source_lang}) doesn't match language of .json file (#{data['language']}).")
		language_matching = false
	end
	return language_matching
end

def check_source_field(short_title, page, source_key)
	# Check by key if source-field exists and if value is present.
	# The parameter 'page' stands for an incoming mainpage or subpage.
	if page[source_key].nil? == true
		$log.error("No field '#{source_key}' found in this page: #{short_title} - Should be generated by scraper.")
		source_field_okay = false
	elsif page[source_key].empty? == true
		$log.warn("Field #{source_key} is empty in page: #{short_title}. Nothing to translate")
		source_field_okay = false
	else
		source_field_okay = true
	end
end

def check_target_field(short_title, page, target_key, wording)
	# Check by key if taarget-field exists. If its value is already set, ask to overwrite.
	# The parameter 'page' stands for an incoming mainpage or subpage.
	if page[target_key].nil? == true
		$log.error("No target key '#{target_key}' found in this page: #{short_title} - Should be generated by scraper.")
		target_field_okay = false
	#elsif page[target_key].empty? == false
		# ask to overwrite is deprecated since the file is not overwritten but generated with "translated" suffix
		#$log.warn("Translation already exists in #{wording}: #{short_title}")
		#target_field_okay = get_parameter_from_option_or_ask($options[:target_field_okay], "Overwrite it? [y/n] : ", "n") == "y"
	else
		target_field_okay = true
	end
end

def build_url(source_lang, target_lang, key)
	url = "https://translate.yandex.net/api/v1.5/tr.json/translate?lang=#{source_lang}-#{target_lang}&key=#{key}"
end

def translate_content(short_title, content, url, wording)		
	
	# Build HTTP POST request
	request = Typhoeus::Request.new(
		url,
		ssl_verifypeer: false,
		method: :post,
		headers: {'Content-Type'=> "application/x-www-form-urlencoded;charset=UTF-8"},
		body: {text: content}
	)

	# Handling HTTP errors
	successful = false
	request.on_complete do |response|
		if response.success?
			successful = true
		elsif response.timed_out?
			$log.error("Time out: #{wording} not translated: #{short_title}")
		elsif response.code == 0
			$log.fatal("Could not get a http response: #{response.return_message}")
		else
			$log.fatal("HTTP request failed: Code #{response.code.to_s}")
		end
	end

	request.run
	response = request.response
	result_text = JSON.parse(response.body)
	content = result_text['text'].join

	return successful, content
end

# ---- Main program ----

# Information bout hard-coded stuff
puts
puts "Source and target fields are hard-coded in .rb file: "
puts MAINPAGE_TRANSLATE_FIELDS
puts SUBPAGE_TRANSLATE_FIELDS
puts

# Check Yandex API key
if (defined?(YANDEX_KEY)).nil? == true || YANDEX_KEY.empty? == true
	$log.fatal("No yandex key found. Enter yandex key in .rb file")
	exit
end

# Let user choose source language
source_lang = get_parameter_from_option_or_ask($options[:source_lang], "Enter source language:  ", "de")
say "using source language '#{source_lang}'"

# Let user choose target language
target_lang = get_parameter_from_option_or_ask($options[:target_lang], "Enter target language:  ", "en")
say "using target language '#{target_lang}'"

if source_lang == target_lang
	$log.fatal("Source language can't be the same as target language") 
	exit
end

# Let user choose files for translation
filenames = list_files()

# For each user-selected file
filenames.each do |filename|
	
	# Parse .json file
	data, success = parse_json(filename)
	next if success == false

	# Count translations and pages
	success_counter = 0
	page_counter = 0

	# For each scenario in file do
	data['scenarios'].each do |scenario|
		
		# ---- MAINPAGES ----
		page_counter += 1
		inner_success_counter = 0 # reset
		title = "title_" + source_lang
		short_title = build_short_title(scenario[title])
	
		# When choosing multiple files, it is possible, that one file has another language 
		# than the source language choosen by user. If this happens jump to next file.
		language_matching = check_language_combination(data, source_lang)
		break if language_matching == false

		# Build yandex.ru url
		url = build_url(source_lang, target_lang, YANDEX_KEY)

		MAINPAGE_TRANSLATE_FIELDS.each do |field|
			# Check if source/target fields exist & are filled
			source_okay = check_source_field(short_title, scenario, field[0])
			target_okay = check_target_field(short_title, scenario, field[1], "mainpage")

			# Translate and count successful translations
			successful = false # reset
			if source_okay && target_okay
				successful, scenario[field[1]] = translate_content(short_title, scenario[field[0]], url, "Mainpage")
			end
			inner_success_counter += 1 if successful
		end
		if inner_success_counter == MAINPAGE_TRANSLATE_FIELDS.length
			$log.info("Mainpage translated: #{short_title}")
			success_counter += 1
		end

		# ---- SUBPAGES ----
		if TRANSLATE_SUBPAGES
			subpages = scenario['subpages']
			if subpages.nil? == false
				subpages.each do |subpage|
					
					page_counter += 1
					inner_success_counter = 0 # reset
					short_title = build_short_title(subpage['subpage_title_de'])

					SUBPAGE_TRANSLATE_FIELDS.each do |field|
						# Check if source/target fields exist & are filled
						source_okay = check_source_field(short_title, subpage, field[0])
						target_okay = check_target_field(short_title, subpage, field[1], "subpage")			

						# Translate and count successful translations
						successful = false # reset
						if source_okay && target_okay
							successful, subpage[field[1]] = translate_content(short_title, subpage[field[0]], url, "Mainpage")
						end
						inner_success_counter += 1 if successful
					end
					if inner_success_counter == SUBPAGE_TRANSLATE_FIELDS.length
						$log.info("Subpage translated: #{short_title}")
						success_counter += 1
					end
				end				
			end
		end
	end
	write_json(data, filename, success_counter, page_counter)
end