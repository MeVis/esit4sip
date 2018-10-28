article_url = "http://www.esit4sip.eu/#knowledgebase?article=";

$( document ).ready(function() {
	uri = new URI(); // Uri object for url manipulation
	var fragment = uri.fragment(); // get scenario ID
	
	console.log("Redirecting for id: " + fragment);
	var scenario_url = rebuild_scenario_url(fragment, article_url);
	console.log("Redirecting to: " + scenario_url);

	$('#url').attr("href", scenario_url);

/*
	window.setTimeout(function(){
		window.location = scenario_url;
	}, 5000);

*/

	var count = 7;
	setInterval(function(){
		count--;
		$('#countdown').text(count);
		if (count == 0) {
			window.location = scenario_url;
		}
	},1000);


});

function rebuild_scenario_url(fragment) {
	// build url for redirecting
	return article_url + fragment;
}