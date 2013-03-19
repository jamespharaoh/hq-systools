require "tempfile"
require "tmpdir"
require "webrick"

require "hq/systools/monitoring/log-monitor-client-script"

# web server to recieve events

$web_config = {
	:Port => 10000 + rand(55535),
	:AccessLog => [],
	:Logger => WEBrick::Log::new("/dev/null", 7),
	:DoNotReverseLookup => true,
}

$web_server =
	WEBrick::HTTPServer.new \
		$web_config

Thread.new do
	$web_server.start
end

at_exit do
	$web_server.shutdown
end

$web_server.mount_proc "/submit-log-event" do
	|request, response|

	event = MultiJson.load request.body

	$events_received << event

end

# initialisation

Before do

	@configs = {}
	@logfiles = {}

	@script = HQ::SysTools::Monitoring::LogMonitorClientScript.new

	@script.stdout = StringIO.new
	@script.stderr = StringIO.new

	$events_received = []

end

# steps

Given /^a config file "(.*?)":$/ do
	|config_name, config_contents|
	@configs[config_name] = config_contents

end

Given /^a logfile "(.*?)":$/ do
	|logfile_name, logfile_contents|
	@logfiles[logfile_name] = logfile_contents
end

When /^I run log\-monitor\-client with config "(.*?)"$/ do
	|config_name|

	# work in a temporary dir

	Dir.mktmpdir do
		|temp_dir|

		Dir.chdir temp_dir

		# write log files

		@logfiles.each do
			|logfile_name, logfile_contents|

			File.open logfile_name, "w" do
				|logfile_io|

				logfile_io.print logfile_contents

			end

		end

		# write config file

		Tempfile.open "log-monitor-client-steps-" do
			|config_temp|

			config_content = @configs[config_name]

			server_url =
				"http://localhost:%s/submit-log-event" % [
					$web_config[:Port],
				]

			config_content.gsub! "${server-url}", server_url

			config_temp.print config_content
			config_temp.flush

			# run script

			@script.args = [ "--config", config_temp.path ]
			@script.main

		end
		
	end

end

Then /^no events should be submitted$/ do
	$events_received.should == []
end

Then /^the following events should be submitted:$/ do
	|events_str|
	events_expected = YAML.load "[#{events_str}]"
	$events_received.should == events_expected
end

