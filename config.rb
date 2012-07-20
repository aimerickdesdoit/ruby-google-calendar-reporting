require 'rubygems'

env = (ENV["RACK_ENV"] || ENV["RAILS_ENV"] || "development").to_sym

# Set up gems listed in the Gemfile.
gemfile = File.expand_path('../Gemfile', __FILE__)
begin
  ENV['BUNDLE_GEMFILE'] = gemfile
  require 'bundler'
  Bundler.setup
rescue Bundler::GemNotFound => e
  STDERR.puts e.message
  STDERR.puts "Try running `bundle install`."
  exit!
end if File.exist?(gemfile)

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, env) if defined?(Bundler)

require 'active_support'
require 'active_support/core_ext/object/conversions'
require 'action_mailer'
require 'thor'

CONFIG = YAML.load(File.open('config.yml'))

ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.raise_delivery_errors = true
ActionMailer::Base.smtp_settings = CONFIG['action_mailer']['smtp_settings']