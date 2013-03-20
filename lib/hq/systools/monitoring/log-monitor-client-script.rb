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
		read_cache
		perform_checks
		write_cache
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

		@cache_elem =
			@config_elem.find_first("cache")

		@client_elem =
			@config_elem.find_first("client")

		@server_elem =
			@config_elem.find_first("server")

		@service_elems =
			@config_elem.find("service").to_a

	end

	def read_cache

		cache_path = @cache_elem["path"]

		if File.exist? cache_path

			@cache =
				YAML.load File.read cache_path

		else

			@cache = {
				files: {},
			}

		end

	end

	def write_cache

		cache_path = @cache_elem["path"]
		cache_temp_path = "#{cache_path}.new"

		File.open cache_temp_path, "w" do
			|cache_temp_io|

			cache_temp_io.write YAML.dump @cache
			cache_temp_io.fsync

		end

		File.rename cache_temp_path, cache_path

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

					file_mtime = File.mtime file_name

					cache_file = @cache[:files][file_name]

					if cache_file && file_mtime == cache_file[:mtime]
					puts "SKIPPING"
						next
					end

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

					@cache[:files][file_name] = {
						mtime: file_mtime,
					}

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
