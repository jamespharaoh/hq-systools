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

				max_before =
					match_elems.map {
						|match_elem|
						(match_elem["before"] || 0).to_i
					}.max

				max_after =
					match_elems.map {
						|match_elem|
						(match_elem["after"] || 0).to_i
					}.max

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
					file_size = File.size file_name

					# fast check for modified files

					cache_file = @cache[:files][file_name]

					if cache_file &&
						file_mtime == cache_file[:mtime] &&
						file_size == cache_file[:size]
						next
					end

					# scan the file for matching lines

					mode = cache_file ? :scan : :report

					File.open file_name, "r" do
						|file_io|

						file_reader =
							ContextReader.new \
								file_io,
								max_before + max_after + 1

						file_hash = 0

						# check if the file has changed

						if cache_file
pp cache_file

							if file_size < cache_file[:size]

puts "CHANGED0"
								changed = true

							else

								changed = false

puts "LINES: #{cache_file[:lines]}"
								cache_file[:lines].times do

									line = file_reader.gets
puts "LINE"

									unless line
puts "CHANGED1"
										changed = true
										break
									end

									file_hash = [ file_hash, line.hash ].hash

								end

								if file_hash != cache_file[:hash]
puts "CHANGED2 #{file_hash} #{cache_file[:hash]}"
									changed = true
								end

							end

						end

						# go back to start if it changed

						if changed
							file_io.seek 0
							file_reader.reset
							file_hash = 0
						end

						# scan the new part of the file

						while line = file_reader.gets

							file_hash = [ file_hash, line.hash ].hash

							# check for a match

							match_elem =
								match_elems.find {
									|match_elem|
									line =~ /#{match_elem["regex"]}/
								}

							# report the match

							if match_elem

								# get context

								lines_before =
									file_reader.lines_before \
										(match_elem["before"] || 0).to_i + 1

								lines_before.pop

								lines_after =
									file_reader.lines_after \
										(match_elem["after"] || 0).to_i

								# send event

								submit_event({
									type: match_elem["type"],
									source: {
										class: @client_elem["class"],
										host: @client_elem["host"],
										service: service_elem["name"],
									},
									location: {
										file: file_name,
										line: file_reader.last_line_number,
									},
									lines: {
										before: lines_before,
										matching: line,
										after: lines_after,
									},
								})
	
							end

						end

						# save the file's current info in the cache

						@cache[:files][file_name] = {
							mtime: file_mtime,
							size: file_size,
							lines: file_reader.next_line_number,
							hash: file_hash,
						}

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

	class ContextReader

		def initialize source, buffer_size

			@source = source
			@buffer_size = buffer_size

			@buffer = Array.new @buffer_size

			reset

		end

		def lines_before_count
			return @buffer_cursor - @buffer_start
		end

		def lines_after_count
			return @buffer_end - @buffer_cursor
		end

		def lines_before count
			count = [ count, lines_before_count ].min
			return (0...count).map {
				|i| @buffer[(@buffer_cursor - count + i) % @buffer_size]
			}
		end

		def lines_after count
			count = [ count, @buffer_size ].min
			while lines_after_count < count
				read_next_line or break
			end
			count = [ count, @buffer_end - @buffer_cursor].min
			return (0...count).map {
				|i| @buffer[(@buffer_cursor + i) % @buffer_size]
			}
		end

		def read_next_line

			# read a line

			line = @source.gets
			return false unless line

			line.strip!
			line.freeze

			# shrink buffer if full

			if @buffer_end - @buffer_start == @buffer_size
				@buffer_start += 1
			end

			# add line to buffer

			@buffer[@buffer_end % @buffer_size] = line
			@buffer_end += 1

			return true

		end

		def gets

			# make sure the next line is in the buffer

			if lines_after_count == 0
				read_next_line or return nil
			end

			# return the line, advancing the cursor

			ret = @buffer[@buffer_cursor % @buffer_size]
			@buffer_cursor += 1
			return ret

		end

		def last_line_number
			raise "No last line" unless @buffer_cursor > 0
			@buffer_cursor - 1
		end

		def next_line_number
			@buffer_cursor
		end

		def reset
			@buffer_start = 0
			@buffer_cursor = 0
			@buffer_end = 0
		end

	end

end
end
end
end
