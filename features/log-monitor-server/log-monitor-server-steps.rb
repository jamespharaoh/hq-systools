require "capybara/cucumber"
require "mongo"

require "hq/systools/monitoring/log-monitor-server-script"

$token = (?a..?z).to_a.sample(10).join

# database stuff

$db_names = []

Before do
	@db_names = []
end

def mongo_db_name name
	if @db_names
		@db_names << name unless @db_names.include? name
	end
	$db_names << name unless $db_names.include? name
	"cuke_#{$token}_#{name}"
end

def mongo_conn
	return $mongo if $mongo
	$mongo = Mongo::MongoClient.new "localhost", 27017
	return $mongo
end

def mongo_db name
	mongo_conn[mongo_db_name name]
end

After do

	@db_names.each do
		|db_name|

		mongo_db(db_name).collections.each do
			|coll|
			next if coll.name =~ /^system\./
			coll.drop
		end

	end

end

at_exit do

	$db_names.each do
		|db_name|

		mongo_conn.drop_database mongo_db_name(db_name)

	end

end

# step definitions

Given /^the log monitor server config:$/ do
	|config_string|

	# write config file

	@log_monitor_server_port = 10000 + rand(55535)

	@log_monitor_server_config =
		Tempfile.new "cuke-log-monitor-server-"

	config_string = config_string.clone

	config_string.gsub! "${port}", @log_monitor_server_port.to_s
	config_string.gsub! "${db-host}", "localhost"
	config_string.gsub! "${db-port}", "27017"
	config_string.gsub! "${db-name}", mongo_db_name("logMonitorServer")

	@log_monitor_server_config.write config_string
	@log_monitor_server_config.flush

	@log_monitor_server_script =
		HQ::SysTools::Monitoring::LogMonitorServerScript.new

	@log_monitor_server_script.args = [
		"--config",
		@log_monitor_server_config.path,
		"--quiet",
	]

	@log_monitor_server_script.start

	Capybara.app = @log_monitor_server_script

end

After do

	@log_monitor_server_script.stop \
		if @log_monitor_server_script

	@log_monitor_server_config.unlink \
		if @log_monitor_server_config

end

When /^I submit the following events?:$/ do
	|event_string|

	events_data = YAML.load "[#{event_string}]"

	events_data.each do
		|event_data|

		event_json = MultiJson.dump event_data

		Net::HTTP.start "localhost", @log_monitor_server_port do
			|http|

			request = Net::HTTP::Post.new "/submit-log-event"
			request.body = event_json

			@http_response = http.request request

		end

	end

	@submitted_events = events_data

end

Then /^I should receive a (\d+) response$/ do
	|response_code|
	@http_response.code.should == response_code
end

Then /^the event should be in the database$/ do

	db = mongo_db("logMonitorServer")

	event = db["events"].find.first

	event.should_not be_nil
	event["timestamp"].should be_a Time

	event.delete "_id"
	event.delete "timestamp"

	event.should == @submitted_events.first

end

Then /^the summary should show:$/ do
	|expected_string|

	expected_summary = YAML.load expected_string

	db = mongo_db("logMonitorServer")

	summary =
		db["summaries"].find({
			"_id" => expected_summary["_id"],
		}).first

	summary.should == expected_summary

end

# ui steps

When /^I visit the overview page$/ do
	visit "/"
end

Then /^I should see no summaries$/ do
	page.should have_content "No events have been logged"
end

Then /^I should see (\d+) summar(?:y|ies)$/ do
	|count_str|
	count = count_str.to_i
	find("#summaries").should have_css(".summary", :count => count)
end

Then /^the (\d+(?:st|nd|rd|th)) summary should be:$/ do
	|index_str, fields|

	index = index_str.to_i

	within "#summaries" do

		fields.hashes.each do
			|row|
			find(".#{row["name"]}").text.should == row["value"]
		end

	end

end
