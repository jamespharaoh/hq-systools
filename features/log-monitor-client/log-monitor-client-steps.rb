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

$web_server_url =
	"http://localhost:%s/submit-log-event" % [
		$web_config[:Port],
	]

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

# set up and tear down

Before do

	$events_received = []

	@old_dir = Dir.pwd
	@temp_dir = Dir.mktmpdir
	Dir.chdir @temp_dir

end

After do

	FileUtils.remove_entry_secure @temp_dir
	Dir.chdir @old_dir

end

# steps

def write_file file_name, file_contents

	file_contents.gsub! "${server-url}", $web_server_url

	File.open file_name, "w" do
		|file_io|
		file_io.print file_contents
	end

end

Given /^(?:I have updated|a) file "(.*?)":$/ do
	|file_name, file_contents|

	write_file file_name, file_contents

end

Given /^I have updated file "(.*?)" without changing the timestamp:$/ do
	|file_name, file_contents|

	file_mtime = File.mtime file_name

	write_file file_name, file_contents

	file_atime = File.atime file_name
	File.utime file_atime, file_mtime, file_name

end

Given /^I have updated file "(.*?)" changing the timestamp:$/ do
	|file_name, file_contents|

	file_mtime = File.mtime file_name

	write_file file_name, file_contents

	file_atime = File.atime file_name
	File.utime file_atime, file_mtime + 1, file_name

end

When /^I have run log\-monitor\-client with config "(.*?)"$/ do
	|config_name|

	script = HQ::SysTools::Monitoring::LogMonitorClientScript.new

	script.stdout = File.open "/dev/null", "w"
	script.stderr = File.open "/dev/null", "w"

	script.args = [ "--config", config_name ]
	script.main
		
end

When /^I run log\-monitor\-client with config "(.*?)"$/ do
	|config_name|

	@script = HQ::SysTools::Monitoring::LogMonitorClientScript.new

	@script.stdout = StringIO.new
	@script.stderr = StringIO.new

	@script.args = [ "--config", config_name ]
	@script.main
		
end

Then /^no events should be submitted$/ do
	$events_received.should == []
end

Then /^the following events should be submitted:$/ do
	|events_str|
	events_expected = YAML.load "[#{events_str}]"
	$events_received.should == events_expected
end
