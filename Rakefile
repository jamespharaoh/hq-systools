require "rspec/core/rake_task"
require "cucumber/rake/task"

task :default => [ :spec, :features ]

desc "Run specs"
RSpec::Core::RakeTask.new :spec do
	|task|

	task.pattern = "spec/**/*-spec.rb"

	task.rspec_opts = [

		"--format progress",

		"--format html",
		"--out results/rspec.html",

		"--format RspecJunitFormatter",
		"--out results/rspec.xml",

	].join " "

	task.ruby_opts = [
		"-I lib",
	].join " "

end

desc "Run acceptance tests"
Cucumber::Rake::Task.new :features do
	|task|

	task.cucumber_opts = [

		"features",

		"--format progress",

		"--format junit",
		"--out", File.expand_path("results/features"),

		"--format html",
		"--out", File.expand_path("results/features.html"),

	].join " "

end
