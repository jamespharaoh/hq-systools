require "hq/tools/getopt"
require "net/http"
require "multi_json"
require "xml"

module HQ
module SysTools
module Monitoring
class LogMonitorClientScript

	attr_accessor :args
	attr_accessor :status

	attr_accessor :stdout
	attr_accessor :stderr

	def main
		process_args
		read_config
		perform_checks
	end

	def process_args

		@opts, @args =
			Tools::Getopt.process @args, [

				{ :name => :config,
					:required => true },

			]

		@args.empty? \
			or raise "Extra args on command line"

	end

	def read_config

		config_doc =
			XML::Document.file @opts[:config]

		@config_elem =
			config_doc.root

		@client_elem =
			@config_elem.find_first("client")

		@server_elem =
			@config_elem.find_first("server")

		@service_elems =
			@config_elem.find("service").to_a

	end

	def perform_checks

		@service_elems.each do
			|service_elem|

			fileset_elems = service_elem.find("fileset").to_a

			fileset_elems.each do
				|fileset_elem|

				scan_elems = fileset_elem.find("scan").to_a
				match_elems = fileset_elem.find("match").to_a

				# find files

				file_names =
					scan_elems.map {
						|scan_elem|
						Dir[scan_elem["glob"]]
					}.flatten

				# scan files

				file_names.each do
					|file_name|

					File.open file_name, "r" do
						|file_io|

						line_number = 0

						while line = file_io.gets

							line.strip!

							# check for a match

							match_elem =
								match_elems.find {
									|match_elem|
									line =~ /#{match_elem["regex"]}/
								}

							next unless match_elem

							# report the match

							if match_elem
								submit_event({
									type: match_elem["type"],
									source: {
										class: @client_elem["class"],
										host: @client_elem["host"],
										service: service_elem["name"],
									},
									location: {
										file: file_name,
										line: line_number,
									},
									prefix: [],
									line: line,
									suffix: [],
								})
							end

							line_number += 1

						end

					end

				end

			end

		end

	end

	def submit_event event

		url =
			URI.parse @server_elem["url"]

		http =
			Net::HTTP.new url.host, url.port

		request =
			Net::HTTP::Post.new url.path

		request.body =
			MultiJson.dump event

		response =
			http.request request

	end

end
end
end
end
