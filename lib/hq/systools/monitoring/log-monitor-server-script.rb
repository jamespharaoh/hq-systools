require "mongo"
require "rack"
require "webrick"
require "xml"

require "hq/tools/getopt"

module HQ
module SysTools
module Monitoring
class LogMonitorServerScript

	attr_accessor :args
	attr_accessor :status

	def initialize
		@status = 0
	end

	def main
		setup
		trap "INT" do
			@web_server.shutdown
		end
		run
	end

	def start
		setup
		Thread.new { run }
	end

	def stop
		@web_server.shutdown
	end

	def setup
		process_args
		read_config
		connect_db
		init_server
	end

	def run
		@web_server.start
	end

	def process_args

		@opts, @args =
			Tools::Getopt.process @args, [

			{ :name => :config,
				:required => true },

			{ :name => :quiet,
				:boolean => true },

		]

		@args.empty? \
			or raise "Extra args on command line"

	end

	def read_config

		config_doc =
			XML::Document.file @opts[:config]

		@config_elem =
			config_doc.root

		@server_elem =
			@config_elem.find_first("server")

		@db_elem =
			@config_elem.find_first("db")

	end

	def connect_db

		@mongo =
			Mongo::MongoClient.new \
				@db_elem["host"],
				@db_elem["port"].to_i

		@db =
			@mongo[@db_elem["name"]]

	end

	def init_server

		@web_config = {
			:Port => @server_elem["port"].to_i,
			:AccessLog => [],
		}

		if @opts[:quiet]
			@web_config.merge!({
				:Logger => WEBrick::Log::new("/dev/null", 7),
				:DoNotReverseLookup => true,
			})
		end

		@web_server =
			WEBrick::HTTPServer.new \
				@web_config

		@web_server.mount "/", Rack::Handler::WEBrick, self

	end

	def call env

		case env["PATH_INFO"]

		when "/submit-log-event"
			submit_log_event env

		when "/"
			overview env

		else
			raise "Not found"

		end

	end

	def submit_log_event env

		# decode it

		event = MultiJson.load env["rack.input"].read

		# add a timestamp

		event["timestamp"] = Time.now

		# insert it

		@db["events"].insert event

		# update summary

		summary =
			@db["summaries"].find({
				"_id" => event["source"],
			}).first

		summary ||= {
			"_id" => event["source"],
			"combined" => { "new" => 0, "total" => 0 },
			"types" => {},
		}

		summary["types"][event["type"]] ||=
			{ "new" => 0, "total" => 0 }

		summary["types"][event["type"]]["new"] += 1
		summary["types"][event["type"]]["total"] += 1

		summary["combined"]["new"] += 1
		summary["combined"]["total"] += 1

		@db["summaries"].save summary

		# respond successfully

		return 202, {}, []

	end

	def overview env

		headers = {}
		html = []

		headers["content-type"] = "text/html"

		html << "<! DOCTYPE html>\n"
		html << "<html>\n"
		html << "<head>\n"

		html << "<title>Overview - Log monitor</title>\n"

		html << "</head>\n"
		html << "<body>\n"

		html << "<h1>Overview - Log monitor</h1>\n"

		html << "<p>No events have been logged</p>\n"

		html << "</body>\n"
		html << "</html>\n"

		return 200, headers, html

	end

end
end
end
end
