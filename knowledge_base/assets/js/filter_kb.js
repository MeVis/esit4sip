// Uri object for url manipulation
uri = new URI();

var filepath = "data/"
var tags_file = filepath + "tags.json";
var articles_file = filepath + "articles.json";
var infrastructure_file = filepath + "infrastructure.json";

// true if article is shown in GUI
var article_is_shown = true;

// Object language codes:  English => en
var language_code = {english:"en", german:"de", greek:"el"};
var code_language = {en:"English", de:"German", el:"Greek"};
// Sorting object for filter.js
var sort_options = {'name': 'asc'};
var results;

var infrastructures = [
  {
    "id": "infra-paed-ml",
    "tags": ["DesktopComputer", "Tablets", "Laptop", "Projector", "2dPrinter", "Scanner", "Pclab"]
  },
  {
    "id": "mobility",
    "tags": ["Laptop","Tablets","WiFi", "InClass", "AroundTheSchool", "ComputersAroundTheLabRoom", "Projector"]
  },
  {
    "id": "always_available",
    "tags": ["DesktopComputer", "Laptop", "Lan", "WiFi", "InClass", "ComputersAroundTheLabRoom", "InteractiveWhiteboard", "Projector", "VideoPlayer"]
  }      
];


// ---------------------------------------------
function set_history(query) {
	if(history.pushState) {
		console.log("Using replaceState() to update browser url");
		if(query.length > 0) {
			history.replaceState(null, null, '#knowledgebase?'+query);
		}
		else {
			history.replaceState(null, null, '#knowledgebase');
		}
	}
	else {
		console.log("Using location.hash to update browser url");
		if(query.length > 0) {
			location.hash = 'knowledgebase?'+query;
		}
		else {
			location.hash = 'knowledgebase';
		}
	}
}

function get_query(uri) {
	// If a query exists, get it as object and restore the current url.
	new_uri = new URI();
	if(uri.query().length > 0) {
		new_uri = uri;
		console.log("Regained query from url query");
	}
	else {
		fragment = new URI(uri.fragment());
		new_uri.query(fragment.query());
		console.log("Regained query from url fragment");
	}
	return new_uri;
}

function restore_state(uri, articles_carry) {
	// Function get_query (runs previously) restores the uri.
	// This function restores the active filters and the shown article with the uri.
	// It gets a data map whit this schema: Key: devices, Value: laptops (or array)
	if(uri.query().length > 0) {
		var query_map = uri.search(true);
		$.each( query_map, function(key,value){
			// Restore article by its ID
			if(key == "article") {
				id = query_map.article;
				$('#articles').hide();
				show_translations(id, articles_carry);
				show_article(id);
				console.log("Restored article: " + value);
			}
			// Restore sortBy by its value (=ID)
			else if(key == "sortBy") {
				// Class management
				$(".sort-ul").find('*').removeAttr('class');
				$('#'+value).addClass("active");
				$('#sort-text').text($('#'+value).text());
				sort_options = build_sort_options(value);

				uri.addQuery("sortBy", value);
				set_history(uri.query());
				//FJS.filter(); // trigger filter
				console.log("Restored sortBy: " + value);
			}
			// Restore sortBy by its value
			else if(key == "perPage") {
				$('.per-page option[value='+value+']').prop('selected', true);
				$('.per-page').trigger('change');
			}			
			// Restore filters by their IDs
			else {
				if($.isArray(value)) {
					$.each( value, function(i, val){
						$('#'+val).trigger('click');
					});
				}
				else {
					$('#'+value).trigger('click');
				}
			console.log("Restored filters");
			}
		});
	}
}

function get_init_page(uri) {
	var page = 1;
	if(uri.query().length > 0) {
		page = uri.search(true).page
		page = parseInt(page) || 1;
		if(page < 0) {
			page = 1;
		}
	}
	return page;
}

function get_sortby(uri) {
	// This function has to be run before the callback 'shortResult' starts.
	// That's why we get 'sortBy' from the query at this early point. 
	// The select of the DOM element is done in function 'restore_state'.
	// Notice: var sort_options is global
	if(uri.query().length > 0) {
		sort_options = build_sort_options(uri.search(true).sortBy);
	}
}

function list_filters(tag_groups) {			
	// Append all active user-choosen filters in DOM element #active-filters
	// If checkbox 'all' is selected, only add this to query and list.
	$('#active-filters').find('a').remove();
	$.each(tag_groups, function(i, element) {
		var group_id = element.groupname.toLowerCase().replace(" ","_");
		var group_criteria = group_id + "_criteria";
		var group_all = "all_" + group_id;  
		if($('#'+group_all).prop('checked')) {
			$('#active-filters').append('<a class="'+group_all+'">'+group_id+' all</a>');
		}
		else {
			$('#'+group_criteria+' input:checked').each(function() {
				var check_id = $(this).attr('id');
				var check_value = $(this).attr('value');
				$('#active-filters').append('<a class="'+check_id+'">'+check_value+'</a>');
			});
		}
	});
	// If any checkbox is active, show 'clear_all' and active-filters
	if($('#facets input:checked').length > 0) {
		$('#clear_all').show();
		$('#active-filters').show();
	}
	else {
		$('#clear_all').hide();
		$('#active-filters').hide();
	}
}

function update_query(tag_groups) {			
	// Add active filters to query for updating browser URL later.
	$.each(tag_groups, function(i, element) {
		var group_id = element.groupname.toLowerCase().replace(" ","_");
		var group_criteria = group_id + "_criteria";
		var group_all = "all_" + group_id; 
		if($('#'+group_all).prop('checked')) {
			uri.addQuery(group_id, group_all);
		}
		else {
			$('#'+group_criteria+' input:checked').each(function() {
				var check_id = $(this).attr('id');
				uri.addQuery(group_id, check_id);
			});
		}
	});
}

function refresh_numbers(tag_groups, result, jQ) {
	total_articles = result.length;
	$('#total_articles').text(total_articles);
	$.each(tag_groups, function(i, element) {
		var group_id = element.groupname.toLowerCase().replace(" ","_");
		var group_criteria = group_id + "_criteria";
		var checkboxes  = $("#"+group_criteria+" :input:gt(0)");
		checkboxes.each(function(){
			var c = $(this), count = 0
			if(result.length > 0){              
				count = jQ.where({ [group_id]: c.val() }).count;
			}
			c.next().text(c.val() + ' (' + count + ')')
		});
	});
}

function build_filter_html(tag_groups){
	// For each tag group do: Build html of facet filters in the left sidebar	
	$.each(tag_groups, function(i, element) {
		var group_id = element.groupname.toLowerCase().replace(" ","_");
		var group_criteria = group_id + "_criteria";
		var group_all = "all_" + group_id;
		// Add HTML container and fieldset for each tag-group
		$("#facets").append(
			'<div class="panel panel-default kb-panel">' +
				'<div class="panel-heading collapsed" data-toggle="collapse" data-target="#collapse-'+group_id+'">'+element.groupname+'</div>' +
				'<div id="collapse-'+group_id+'" class="panel-collapse collapse">' +
					'<div class="panel-body" id="'+group_criteria+'">' + 
						'<div class="checkbox"><label><input type="checkbox" value="All" id="'+group_all+'"><span>Toggle all</span></label></div>' +
					'</div>' +
				'</div>' + 
			'</div>'
		);

		// For each tag do: Append checkboxes to the fieldset.
		// Key: bs_Devices_Laptop, Value: laptops
		$.each(element.tags, function(key, val) {
			var tag_id = titleCase(val.replace(/[^a-z0-9]+/gi, ' '));
			$("#"+group_criteria).append(
				'<div class="checkbox"><label>' + 
					'<input id="'+tag_id+'" type="checkbox" value="'+val+'">' +
					'<span>'+val+'</span>' +
				'</label></div>'
			);
		});
		// Each facet contains the function 'toggle all checkboxes'.
		// Add click function to (de-) activate the checks of each facet.
		$('#'+group_all).on('click', function(){
			$('#'+group_criteria+' :checkbox').prop('checked', $(this).is(':checked'));
		});
	});	
}

// UNUSED // DEPRECATED?
function selected_languages() {
	var selected_lang = new Array;
	$('#language_criteria input:checked').each(function() {
		var check_id = $(this).attr('id'); // e.g. English
		selected_lang.push(language_code[check_id.toLowerCase()]);
	});
	return selected_lang;
}

function show_article(id) {
	// Load article html file and append it
	// Hide result list and show single article
	var file = filepath + id + ".html"
	$('#article').empty();
	$( "#article" ).load(file, function() {
		active_translation(id);
		//$('#articles-header').hide();
		$('#articles').hide();
		$('.pagination').hide();
		$('#article-container').show();
		uri.removeQuery("article");
		uri.addQuery("article", id);
		share_popover(id, uri);
		set_history(uri.query());
		console.log( "Article was loaded: " + id);

		// Set global status
		article_is_shown = true;

		cleaned_id = clean_id(id);
		sparql_canidothis(cleaned_id);

		// "See the original version <a>here</a>"
		if($('#original_switch').length){
			var switch_id = clean_id(id) + "_" + $("#original_switch").attr("class"); // e.g.: 12xy_en
			$("#original_switch").html('<a id="' + switch_id + '" class="language_link">here</a>');		
			$("#original_switch").click(function(){
				show_article(switch_id);
			});
		}
	});	
}

function hide_article() {
	uri.removeQuery("article");
	set_history(uri.query());
	$('#article-container').hide();
	$("#language-dropdown").hide();
	//$('#articles-header').show();
	$('#articles').show();
	$('.pagination').show();
	console.log("Hiding article");
	article_is_shown = false;
}

function check_translations(id, articles_carry, lang_code) {
	// This function checks if for a given language code a translation is available
	// Example: User clicks on a greek result/thumbnail --> The greek translation should be shown
	// Problem: The language is gained from a scenario itself but from a bs_navigation_tag!
	// If an author forgets to add the language tag, we return the ID unchanged.

	// Get full translations
	var translations = new Array;
	$.each(articles_carry, function(i, element) {
		if(element.id == id) {
			translations = element.translations;
		}		
	});

	// Iterate over translations
	// If en translation is available: overwrite id
	if(translations.length > 0) {
		$.each(translations, function(i, element) {
			if(element.language == "en") {
				// old: id = id + '_en'
				id = id + '_' + lang_code
				console.log("Found english translation: " + id);
			}
		});
	}
	return id;
}

function show_translations(id, articles_carry) {
	// Appends available translations into  dropdown '#language-list'

	// Clear DOM from existing translation links
	// Clear ID from '_en' or '_de'...
	$('#language-list').empty();
	var code = clean_language_code(id);

	id = clean_id(id);
	$('#language-dropdown').html('Language: ' + code_language[code] + '<span class="caret"></span>');

	var translations = new Array;
	$.each(articles_carry, function(i, element) {
		if(element.id == id) {
			translations = element.translations;
		}		
	});
	if(translations.length > 0) {
		$("#language-dropdown").show();
		$.each(translations, function(i, element) {
			$('#language-list').append(
				'<li><a id="'+id+'_'+element.language+'" class="language_link">' + code_language[element.language] + '</a></li>'
			);
			/*
			$('#languages').append(
				'<a id="'+id+'_'+element.language+'" class="language_link">' + code_language[element.language] + '</a>'
			);*/
		});
	}
	else {
		$("#language-dropdown").hide();
	}	
}

function active_translation(id) {
	// Adds class 'active' to language switch if its ID is present
	var code = clean_language_code(id);
	$('#language-list > li > a').removeClass('active');
	$('#'+id).addClass("active");
	$('#language-dropdown').html('Language: ' + code_language[code] + '<span class="caret"></span>');
}

function clean_id(id) {
	// Clear ID from '_en' or '_de'...
	var position = id.indexOf("_");
	if(position > 0) {
		id = id.slice(0,position);
	}
	return id;
}

function clean_language_code(id) {
	// Return 'en' or 'de'...
	var position = id.indexOf("_");
	if(position > 0) {
		id = id.substr(position+1);
	}
	return id;
}

function result_warning(result) {
	// Shows a warning, if the user selection returns no results
	if(result.length == 0) {
		$('#result-warning').show();
		$('#sort-by').hide();
		$('.per-page').hide();

	}
	else {
		$('#result-warning').hide();
		$('#sort-by').show();
		$('.per-page').show();
	}
}

function show_pagination(result) {
	var per_page = parseInt($( ".per-page option:selected" ).text());
	if (result.length/per_page <= 1) {
		$('.pagination').hide();
	}
	else {
		$('.pagination').show();
	}
}

function share_popover(id, uri) {
	$('#share-url').text("http://www.esit4sip.eu/preview/#knowledgebase?article="+id);
}

// ---------------------------------------------
// Helper function titleCase: hello world --> HelloWorld
// Source: https://medium.freecodecamp.org
function titleCase(str) {
	return str.toLowerCase().split(' ').map(function(word) {
		return word.replace(word[0], word[0].toUpperCase());
	}).join('');
}
// ---------------------------------------------

$(document).ready(function(){

	// Initialize share popover
	// There a user can copy a permalink to scenario
	$('#share-popover').webuiPopover({
		width: '300px', 
		placement:'bottom-left', 
		url:'#share-text', 
		title:'Permalink',
		content:'Content',
		closeable:true}
	);

	// Initialize share copy
	// Functionality provided by clipboard.js
	new ClipboardJS('#copy');

	var tag_groups;
	var tags_loaded = false;
	var articles_carry;
	var articles_loaded = false;
	var total_articles = 0;

	$('#loading').show();
	$('#loading-modal').addClass('loading-modal');

/*
	// Get infrastructure.json
	$.getJSON(infrastructure_file, function (json) {
		var infrastructure = json;
		console.log("infrastructure.json loaded");
		//print_infrastructure_to_modal(infrastructure);
	})
	.error(function() {
		console.log( "Could not load infrastructure.json." );
		$('#infrastructure-modal-content').text("Could not load data. Please try again later.")
	});
*/
	search_by_infrastructure(infrastructures);



	// Get tags.json and articles.json
	// Both files must be loaded before initializing the filters with start().
	$.getJSON(tags_file, function (json) {
		tag_groups = json;
		tags_loaded = true;
		console.log("Tags.json loaded");
		if (tags_loaded && articles_loaded) {
			$('#loading').hide();
			$('#loading-modal').removeClass('loading-modal');
			start(tag_groups, articles_carry);
		}
	})
	.error(function() {
		console.log( "Could not load tags.json." );
		$('.sidebar').css("visibility", "hidden");
		$('#loading-modal').removeClass('loading-modal');
		$('#loading').text("Could not load data. Please try again later.")
	});

// ----------------- GET ARTICLES BY STATIC .json -------------------- 
/*
	$.getJSON(articles_file, function (json) {
		articles_carry = json['scenarios'];
		articles_loaded = true;
		console.log("Articles loaded");
		if (tags_loaded && articles_loaded) {
			$('#loading').hide();
			$('#loading-modal').removeClass('loading-modal');
			start(tag_groups, articles_carry);
		}
	})
	.error(function() {
		console.log( "Could not load articles." );
		$('.sidebar').css("visibility", "hidden");
		$('#loading-modal').removeClass('loading-modal');
		$('#loading').text("Could not load data. Please try again later.")
	});	
*/

// ----------------- GET ARTICLES BY SPARQL --------------------
	// Get data with sparql query. Rebuild articles.json structure
	var queryUrl = ENDPOINT + "?query=" + encodeURIComponent(build_query);
	$.ajax({
		url: queryUrl,
		data: {format: 'json'},
		dataType: 'json',
		type: 'GET',
		success: function(data) {
			console.log("Got articles by sparql");
			//console.log(data);
			articles_carry = build_articles(data);
			console.log(articles_carry);
			articles_loaded = true;
			console.log("Articles loaded");
			if (tags_loaded && articles_loaded) {
				$('#loading').hide();
				$('#loading-modal').removeClass('loading-modal');
				start(tag_groups, articles_carry);
			}			
		},
		error: function() {
			console.log("Error while getting articles via sparql");
			$('.sidebar').css("visibility", "hidden");
			$('#loading-modal').removeClass('loading-modal');
			$('#loading').text("Could not load data. Please try again later.")			
		}
	});

// ----------------- GET ARTICLES BY PHP (CURL) --------------------
/*
	console.log("---- GET ARTICLES -----");
	jQuery.ajax({
		type: "POST",
		url: 'assets/php/get_articles.php',
		dataType: 'json',
		success: function (obj, textstatus) {
			var data = JSON.parse(obj);
			articles_carry = build_articles(data);
			articles_loaded = true;
			console.log("Articles loaded");
			if (tags_loaded && articles_loaded) {
				$('#loading').hide();
				$('#loading-modal').removeClass('loading-modal');
				start(tag_groups, articles_carry);
			}			
		},
		error: function() {
			console.log("Could not load articles");
			$('.sidebar').css("visibility", "hidden");
			$('#loading-modal').removeClass('loading-modal');
			$('#loading').text("Could not load data. Please try again later.")			
		}
	});	
*/

  // --------------- Start ---------------
  // Since the tags are loaded asynchronous, all filter code has to be inside start function.

	function start(tag_groups, articles_carry) {

		$('#articles-header').show();

		uri = get_query(uri); // Get uri query-params for restoring old state
		init_page = get_init_page(uri); // Get init page from uri
		get_sortby(uri); // Init filter with 'sortby' option from uri
		build_filter_html(tag_groups); // Add facets (filter/checkboxes) to DOM

		// Callback is triggered after filter/checkbox is pressed.
		// Notice: Its triggered after initialization too!
		// That's why some code was extracted to click function below.		
		var afterFilter = function(result, jQ){
			list_filters(tag_groups);
			refresh_numbers(tag_groups, result, jQ);
			result_warning(result); // if no results are found
			show_pagination(result); // hide if 0 or 1 pages are available
			results = result; // make it global for click function
		}
		// Click function if filter/checkbox is pressed
		// See callback 'afterFilter' above too.
		$('.checkbox').on('click', function(){
			uri.query(""); // Reset query
			update_query(tag_groups); // Add active filters to query
			set_history(uri.query()); // Update query in browser url
			if(article_is_shown == true) {
				hide_article();
			}
		});

		// Filter Initialisation takes three arguments:
		// (1) data array (2) container for appending (3) options
		// In our case: (1) articles_carry (2) #articles (3) options below
		// Added: init_page sends query page to pagination init()
		var FJS = FilterJS(articles_carry, '#articles', {
			template: '#article-template',
			search: { ele: '#searchbox' },
			callbacks: {
				afterFilter: afterFilter,
				shortResult: shortResult
			},
			pagination: {
				container: '.pagination',
				visiblePages: 5,
				perPage: {
					values: [12, 15, 18],
					container: '#per_page'
				},
			},
			// Custom param. for shown page on startup
			init_page: init_page
		});

		// Add filter criteria
		// With FJS.addCriteria you declare by which fields the articles are filterable.
		// In our case these are the tag groups given in tags.json for e.g.: patterns, domain...
		$.each(tag_groups, function(i, element) {
			var group_id = element.groupname.toLowerCase().replace(" ","_");
			var group_criteria = group_id + "_criteria";
			FJS.addCriteria({field: group_id, ele: '#'+group_criteria+' input:checkbox'});
		});

		// Restore filters, sortby and article with query
		restore_state(uri, articles_carry);
		
		window.FJS = FJS;

		// Avoid flickering in GUI when restoring old state
		// Show containers when results are sorted.		
		if(uri.hasQuery("article") == false) {
			$('#articles-header').fadeIn(800);
			$('#articles').fadeIn(800);
		}

		// Keep articles ordered while searching
		// @param query is a filter.js object
		// Solution by http://yugioh.joelcancela.fr/
		function shortResult(query) {
			query.order(sort_options);
		}	

	} // end start function


	// --------- Click functions ---------

	// Clear a single filter by click on <a> inside #active-filters
	// Get the class of <a> which is the ID of the checkbox too.
	$('#active-filters').on('click', 'a', function(){
		$('#'+$(this).attr('class')).trigger('click');
	});

	// Clear all active filters by click on <a id="clear_all">...
	// Get the class of <a> which is the ID of the checkbox too.
	$('#clear_all').on('click', function(){
		clear_all_filter();
	});

	// Click on result in result list
	// Get scenario id which is set as id in thumbnail
	// Check for existing translations; If english available: overwrite ID
	$('#articles').on('click', '.article-thumbnail', function(){
		var id = $(this).attr('id');
		var lang = $(this).data('lang').toLowerCase(); // e.g. german
		var code = language_code[lang] // e.g. de
		
		scrollToHash('#articles-header');
		show_translations(id, articles_carry);
		id = check_translations(id, articles_carry, code);
		show_article(id);
	});

	// Click on 'back to overview' above article
	$('#back').on('click', function(){
		if(article_is_shown == true) {
			hide_article();
		}
	});

	// Click on language link
	$('#language-list').on('click', 'li > a', function(){
		var id = $(this).attr('id');	
		var language = $(this).text();
		$('#language-dropdown').html('Language: ' + language + '<span class="caret"></span>');
		show_article(id);
	});

	// Click on 'sortby' 
	// Class management, show choosen option in dropdown button,
	// Update query and get sort_options for 'shortResult' callback
	$(".sort-ul li").click(function(){
		var id = $(this).attr('id');
		$(".sort-ul").find('*').removeAttr('class');
		$(this).addClass("active");
		$('#sort-text').text($(this).text());
		uri.removeQuery("sortBy");
		uri.addQuery("sortBy", id);
		set_history(uri.query());
		sort_options = build_sort_options(id);
		FJS.filter(); // trigger filter
	});

	// Click on how many results 'per page'
	$('#per_page').on('change', 'select', function(){
		var per_page = $( ".per-page option:selected" ).text();
		uri.removeQuery("perPage");
		uri.addQuery("perPage", per_page);
		set_history(uri.query());
		show_pagination(results);
	});	

	// Click on pagination: write page to browser url
	/* Deprecated: Page-query management is done in filter.js now
	$('.pagination').on('click', 'li', function(){
		var page = $('.pagination .active a').attr('data-page');
		uri.removeQuery("page");
		uri.addQuery("page", page);
		set_history(uri.query());
	}); */

	// Smooth Scrolling for navbar links and to-top link
	$(".navbar a, .btn-totop").on('click', function (event) {
		scrollToHash(this.hash);
	});	

	$('.nav li').on('click', function(){
		$('.navbar-toggle').trigger( "click" );
	});

	// Load infrastructure
	$('.load-infrastructure').on('click', function(){
		clear_all_filter();
		var id = $(this).attr('id');
		$.each(infrastructures, function(i, elem) {
			if(id == elem.id) {
				$.each(elem.tags, function(i, tag) {
					$("#"+tag).trigger('click');
				});
			}
		});
		$('#modal-infrastructure').modal('hide');

		/* DEPRECATED 
		$('.infrastructure-warning').hide();
		var id = $(this).attr('id');
		var filename = filepath + id + ".json";
		//console.log("Loading infrastructure: " + filename);

		// Get .json
		$.getJSON(filename, function (json) {
			var infrastructure = json;
			console.log(filename + " loaded");
			search_by_infrastructure(infrastructure);
			//update_infrastructure_in_modal(infrastructure);

		})
		.error(function() {
			console.log( "Could not load " + filename );
			$("#"+id).next('.infrastructure-warning').show();
		});
		*/

	});

}); // end document ready


function scrollToHash(hash) {
	// Animate() method for smooth scrolling.
	$('html, body').animate({scrollTop: $(hash).offset().top}, 900, function () {});
}

function clear_all_filter() {
	$('#active-filters a').each(function() {
		$('#'+$(this).attr('class')).trigger('click');
	});
	$('#searchbox').val('');
}

function build_sort_options(id) {
	// Returns sort options dependent on user-choosen option in dropdown
	// The sort_options are used in 'shortResult' callback to set the sorting
	var options;
	if(id == "newest") {
		options = {'version': 'desc'}
	}
	else if (id == "oldest") {
		options = {'version': 'asc'}
	}
	else if (id == "title_asc") {
		options = {'name': 'asc'}
	}
	else if (id == "title_desc") {
		options = {'name': 'desc'}
	}
	return options;
}

function print_infrastructure_to_modal(infrastructure) {
	// DEPRECARTED
	$.each(infrastructure, function(i, element) {
		var group_name = element.groupname;
		var group_id = group_name.toLowerCase().replace(/ /g, "_");;
		var group_criteria = "infra_" + group_id;
		var group_all = "all_" + group_id;

		// Add HTML container and fieldset for each tag-group
		$("#infrastructure-accordion").append(
			'<div class="panel panel-default kb-panel">' +
				'<div class="panel-heading collapsed" data-toggle="collapse" data-target="#collapse-infra-'+group_id+'">'+element.groupname+'</div>' +
				'<div id="collapse-infra-'+group_id+'" class="panel-collapse collapse">' +
					'<div class="panel-body" id="'+group_criteria+'">' + 
						// '<div class="checkbox"><label><input type="checkbox" value="All" id="'+group_all+'"><span>Toggle all</span></label></div>' +
					'</div>' +
				'</div>' + 
			'</div>'
		);

		// For each tag do: Append checkboxes to the fieldset.
		// Key: AudioRecorder, Value: Audio Recorder
		$.each(element.tags, function(key, val) {
			var tag_name = "infra-"+key;
			$("#"+group_criteria).append(
				'<div class="checkbox"><label>' + 
					'<input class="'+tag_name+'" type="checkbox" value="'+val+'">' +
					'<span>'+val+'</span>' +
				'</label></div>'
			);
		});
/*
		// Each facet contains the function 'toggle all checkboxes'.
		// Add click function to (de-) activate the checks of each facet.
		$('#'+group_all).on('click', function(){
			$('#'+group_criteria+' :checkbox').prop('checked', $(this).is(':checked'));
		});
	*/

	});
}

function update_infrastructure_in_modal(infrastructure) {
	// DEPRECARTED
	$.each(infrastructure, function(i, element) {
		var group_name = element.groupname;
		var group_id = group_name.toLowerCase().replace(/ /g, "_");;
		var group_criteria = "infra_" + group_id;
		var group_all = "all_" + group_id;

		$("#"+group_criteria+" input:checkbox").prop('checked',false);

		// For each tag do: Append checkboxes to the fieldset.
		// Key: AudioRecorder, Value: Audio Recorder
		$.each(element.tags, function(key, val) {
			var tag_name = "infra-"+key;
			$("#"+group_criteria).find("."+tag_name).prop('checked',true);
			var tag_id = "infra-"+key;
			$("#"+group_criteria).append(
				'<div class="checkbox"><label>' + 
					'<input id="'+tag_id+'" type="checkbox" value="'+val+'">' +
					'<span>'+val+'</span>' +
				'</label></div>'
			);
		});

	});
}

function search_by_infrastructure(infrastructure) {

}


// --------------- SPARQL ------------------------------
ENDPOINT = "http://www.esit4sip.eu/fuseki/esit4sip/query";
LEARNING = "http://esit4sip.eu/learning#";

function sparql_query(url, subsequent_function) {
	// Runs an asynchronous sparql select query
	// Param URL: Endpoint url + query string
	// Param subsequent_fn: If query-success, run this function

	$.ajax({
		url: url,
		data: {
			format: 'json'
		},
		error: function() {
			console.log("Error while sparql query");
		},
		dataType: 'json',
		success: function(data) {
			console.log("Successfull sparql query");
			// Call subsequent function by given param
			var fn = window[subsequent_function];
			if (typeof fn === "function") fn(data);
		},
		type: 'GET'
	});
}

function build_articles(data) {
	// This function builds the articles.json structure by sparql-query returned data

	var scenarios = data['results']['bindings']; // contains articles from sparql
	var articles = []; // collect scenarios in their new format
	
	$.each(scenarios, function(i, scenario) {
		// Get info from sparql json
		var titles = get_array_value_if_not_empty(scenario['titles']);
		var descriptions = get_array_value_if_not_empty(scenario['descriptions']);
		var id = remove_prefix(scenario['scenario']['value'], LEARNING);		
		var subject = get_array_value_if_not_empty(scenario['domains']);
		var devices = get_array_value_if_not_empty(scenario['devices']);
		var patterns = get_array_value_if_not_empty(scenario['patterns']);
		var tapproachs = get_array_value_if_not_empty(scenario['tapproachs']);
		var ssettings = get_array_value_if_not_empty(scenario['ssettings']);
		var ifunctions = get_array_value_if_not_empty(scenario['ifunctions']);
		var languages = get_array_value_if_not_empty(scenario['languages']);

		var translations = [];
		var translation_codes = get_array_value_if_not_empty(scenario['translations']);
		//console.log(translation_codes);

		// Check wheter there are translations or not
		// If translation is found, rebuild the json structure
		if (translation_codes.length > 0) {
			$.each(translation_codes, function(j, code) {
				
				// Find the correct translation-title with string comparison
				// For example: if lang_code is "en" we have to look for @en
				var at_code = "@"+code;
				var title;
				$.each(titles, function(k, t) {
					if(t.indexOf(at_code) !== -1) {
						title = t;
					}
				});

				// Find the correct translation-description with string comparison
				// For example: if lang_code is "en" we have to look for @en
				// var at_code = "@"+code; defined above
				var summary;
				$.each(descriptions, function(k, d) {
					if(d.indexOf(at_code) !== -1) {
						summary = d;
					}
				});

				translation = {
					"title": title,
					"language": code,
					"summary": summary
				};

				// Add the previously trans. to array
				translations.push(translation);
			});
			
		} else {
			//console.log(" no Trans found");
		}

		// Set for security, voerwritten later
		var title = titles[0];
		var description = descriptions[0];

		// Get the correct title and description by language
		if (languages.length > 0) {
			var lang_code = language_code[languages[0]];
			//console.log("code: "+lang_code);
			title = return_matching_content(titles, lang_code);
			description = return_matching_content(descriptions, lang_code);
		}

		// Remove @en, @de, @el from titles and description
		title = remove_language_info(title);
		description = remove_language_info(description);

		// Write info into objects
		article = {
			"title": title,
			"summary": description,
			"id": id,
			"translations": translations,
			"subject": subject,
			"devices": devices,
			"patterns": patterns,
			"teaching_approach": tapproachs,
			"spatial_settings": ssettings,
			"information_functions": ifunctions,
			"language": languages
		};
		articles.push(article);

	});
	//console.log("Rebuilt articles");
	//console.log(articles);
	return articles;
}

function get_literal_value_if_not_empty(object) {
	value = "";
	if (typeof object !== "undefined") {
		var value = object['value'];
	}
	return value;
}

function get_array_value_if_not_empty(object) {
	value = [];
	if (typeof object !== "undefined") {
		var value = object['value'];
		value = value.split(';');
	}
	return value;
}

function remove_prefix(original, prefix) {
	// Returns a string where the given substring is removed
	// This is usually a prefix, which was defined as constant
	return original.replace(prefix, '');
}

function remove_language_info(str) {
	var content = str;
	if(content.indexOf("@") !== -1) {
		// use constant containing hash table 
		$.each( language_code, function(lang, code){
			content = content.replace("@"+code, '');
		});
	}
	return content;
}

function return_matching_content(arr, code) {
	var returner = arr[0];
	$.each( arr, function(i, elem){
		if(elem.indexOf("@"+code) !== -1) {
			returner = elem;
		}		
	});
	return returner;
}




PREFIXES = [
	"PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>",
	"PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>",
	"PREFIX learning: <http://esit4sip.eu/learning#>",
	"PREFIX infrastructure: <http://esit4sip.eu/infrastructure#>",
	"PREFIX owl: <http://www.w3.org/2002/07/owl#>",
].join(" ");

// sparql query
var query = [
	PREFIXES,
	"SELECT ?affordance ?inst ?tool WHERE {",
		"learning:98c5bf7371b65d947519f8ea0cc22dfb learning:requires ?affordance .",
	"}"
].join(" ");


query = [
	PREFIXES,
	"SELECT ?s ?d WHERE {",
		"?d rdfs:subClassOf* learning:NaturalSciences .",
		"?s learning:hasDomain ?d .",
	"}"
].join(" ");



var build_query = [
	PREFIXES,
	"SELECT ?scenario",
		"(group_concat(distinct ?title;separator=';') as ?titles)",
		"(group_concat(distinct ?description;separator=';') as ?descriptions)",
		"(group_concat(distinct ?domain_labels;separator=';') as ?domains)",
		"(group_concat(distinct ?device;separator=';') as ?devices)",
		"(group_concat(distinct ?pattern;separator=';') as ?patterns)",
		"(group_concat(distinct ?tapproach;separator=';') as ?tapproachs)",
		"(group_concat(distinct ?ssetting;separator=';') as ?ssettings)",
		"(group_concat(distinct ?ifunction;separator=';') as ?ifunctions)",
		"(group_concat(distinct ?language;separator=';') as ?languages)",
		"(group_concat(distinct ?translation;separator=';') as ?translations)",
	"WHERE {",
		"?scenario a learning:Scenario .",
		"?scenario learning:title ?title .",
		"?scenario learning:summary ?description .",
		"optional { ",
		"?scenario learning:hasDomain ?domain . ",
		"?domain rdfs:label ?domain_labels .",
		"}",
		"optional {?scenario learning:hasDevice ?device .}",
		"optional {?scenario learning:implements ?pattern .}",
		"optional {?scenario learning:teaching_approach ?tapproach .}",
		"optional {?scenario learning:spatial_setting ?ssetting .}",
		"optional {?scenario learning:information_function ?ifunction .}",
		"optional {?scenario learning:language ?language .}",
		"optional {?scenario learning:hasTranslation ?translation .}",
	"} group by ?scenario",
].join(" ");


function sparql_affordance_device_tool(id) {
	// Select all affordances of given scenario and all device classes that run a tool offering that affordance
	// See "show_affordance_device_tool" for usage of the returned data
	var affordance_device_tool = [
		PREFIXES,
		"SELECT ?affordance_label ?device_label ?tool_label",
		"WHERE {",
			"learning:"+id+" learning:requires ?affordance .",
			"?affordance rdfs:label ?affordance_label .",
			"?tool rdfs:subClassOf ?resoffers .",
			"?tool rdfs:label ?tool_label .",
			"?resoffers a owl:Restriction .",
			"?resoffers owl:onProperty infrastructure:offers .",
			"?resoffers owl:hasValue ?affordance. ",
			"?device rdfs:subClassOf+ ?resruns .",
			"?device rdfs:label ?device_label .",
			"?resruns a owl:Restriction .",
			"?resruns owl:onProperty infrastructure:runs .",
			"?resruns owl:hasValue ?tool.",
		"}",
	].join(" ");
	// query call
	var queryUrl = ENDPOINT + "?query=" + encodeURIComponent(affordance_device_tool);
	sparql_query(queryUrl, "show_affordance_device_tool");
}

function show_affordance_device_tool(data) {
	
	var rows = data['results']['bindings'];
	console.log(data);

	$.each(rows, function(i, row) {
		// Get info frim sparql json
		var affordance = row['affordance_label']['value'];
		var device = row['device_label']['value'];
		var tool = row['tool_label']['value'];
		console.log(affordance);
		console.log(device);
		console.log(tool);
	});
}

// -------------------------------------------------------------------
function sparql_affordance_tool(id) {
	// Select all affordances of given scenario and all tools offering that affordance
	// See "show_affordance_device_tool" for usage of the returned data
	var affordance_tool = [
		PREFIXES,
		"SELECT DISTINCT ?affordance_label ?tool_label",
			"(group_concat(distinct ?tool_inst_label;separator=\", \") as ?tool_inst_labels) ",
		"WHERE {",
			"learning:98c5bf7371b65d947519f8ea0cc22dfb learning:requires ?affordance .",
			"?affordance rdfs:label ?affordance_label .",
			"?tool rdfs:subClassOf ?resoffers .",
			"?tool rdfs:label ?tool_label .",
			"?tool_inst a ?tool .",
			"?tool_inst rdfs:label ?tool_inst_label .",
			"?resoffers a owl:Restriction .",
			"?resoffers owl:onProperty infrastructure:offers .",
			"?resoffers owl:hasValue ?affordance. ",
			"?device rdfs:subClassOf+ ?resruns .",
			"?device rdfs:label ?device_label .",
			"?resruns a owl:Restriction .",
			"?resruns owl:onProperty infrastructure:runs .",
			"?resruns owl:hasValue ?tool. ",
		"} group by ?affordance_label ?tool_label order by asc(?affordance_label)",
	].join(" ");
	// query call
	console.log(affordance_tool);
	var queryUrl = ENDPOINT + "?query=" + encodeURIComponent(affordance_tool);
	sparql_query(queryUrl, "show_affordance_tool");
}

function show_affordance_tool(data) {
	
	var rows = data['results']['bindings'];
	console.log(data);

	$.each(rows, function(i, row) {
		// Get info frim sparql json
		var affordance = row['affordance_label']['value'];
		var tool = row['tool_label']['value'];
		var tool_inst = row['tool_inst_labels']['value'];
		console.log(affordance);
		console.log(tool);
		console.log(tool_inst);
	});
}

// -------------------------------------------------------------------
function sparql_canidothis(id) {
	// Select all affordances of given scenario and all tools offering that affordance
	// See "show_canidothis" for usage of the returned data
	var tool_affordance = [
		PREFIXES,
		"SELECT DISTINCT ?tool_label ?affordance_label",
		"(group_concat(distinct ?affordance;separator=', ') as ?affordances)",
		"(group_concat(distinct ?alternative_tool_label;separator=', ') as ?alternative_tools)",
		"WHERE {",
		"learning:"+id+" learning:requires ?scenario_affordances .",
		"learning:"+id+" learning:hasTool ?tool .",
		"?tool rdfs:label ?tool_label .",
		"?tool rdfs:subClassOf ?father_class .",
		"?father_class a owl:Restriction .",
		"?father_class owl:onProperty infrastructure:offers .",
		"?father_class owl:hasValue ?affordance.",
		"?affordance rdfs:label ?affordance_label .",

		"?alternative_tool rdfs:subClassOf ?res .",
		"?res a owl:Restriction .",
		"?res owl:onProperty infrastructure:offers .",
		"?res owl:hasValue ?scenario_affordances .",
		"?alternative_tool rdfs:label ?alternative_tool_label .",

		"filter regex(str(?affordance), str(?scenario_affordances)).",
		"} GROUP BY ?tool_label ?affordance_label ORDER BY ASC(?tool)",

	].join(" ");
	// query call
	var queryUrl = ENDPOINT + "?query=" + encodeURIComponent(tool_affordance);	
	sparql_query(queryUrl, "show_canidothis");
}


function show_canidothis(data) {
	// Function builds a table containing: Tool, Affordances, Alternative tool
	// Param data is the incoming json from the sparql query.

	// Empty container before refilling
	$('#alternative-tools-body').empty();

	// Get the result-rows from the incoming data
	var rows = data['results']['bindings'];

	// If there are results for 'can i do this?'
	if(rows.length > 0) {
		console.log("Found "+rows.length+" results for 'can i do this");
		$('#can-i-do-this-btn').show();
		collect_rows = new Array;
		$.each(rows, function(i, row) {
			var tool = get_literal_value_if_not_empty(row['tool'])
			var tool_label = get_literal_value_if_not_empty(row['tool_label'])
			var affordance_arr = get_array_value_if_not_empty(row['affordances']);
			var affordance_label = get_literal_value_if_not_empty(row['affordance_label']);
			var alternative_tools = get_literal_value_if_not_empty(row['alternative_tools']);


			// Remove the tool itself in the alternative tools
			alternative_tools = alternative_tools.replace(tool_label+", ","");
			alternative_tools = alternative_tools.replace(tool_label,"");

			// Collect rows for building table in DOM
			collect_rows.push([tool_label, affordance_label, alternative_tools]);
		});
		//console.log(collect_rows);

		// Build table data object; table head and rows
		var t_data = {
			th: ['Tools', 'Affordances', 'Alternative tool'],
			tr: collect_rows
		}

		var table = new Table(); // Create new table object, insert table data and build it in dom
		table.setHeader(t_data.th).setData(t_data.tr).setTableClass('alternative-tools-table').build('#alternative-tools-body');
	} else {
		$('#can-i-do-this-btn').hide();
		console.log("No results for 'can i do this");
	}
}