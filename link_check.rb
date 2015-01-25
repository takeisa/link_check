#!/usr/bin/env ruby

require 'optparse'
require 'mechanize'

def usage
  puts @option_parser.help
end

def get_scheme_authority(url)
  %r{^(https?\://)([^/]+)} =~ url
  [$1, $2]
end

def uniq(items)
  uniq_items = []

  cur_item = nil
  cur_count = 0

  items.each do |item|
    if cur_item.nil?
      cur_item = item
    end
    if cur_item != item
      uniq_items << [cur_item, cur_count]
      cur_item = item
      cur_count = 0
    end
    cur_count += 1
  end

  if cur_item
    uniq_items << [cur_item, cur_count]
  end

  uniq_items
end

def get_page_and_code(agent, url)
  begin
    page = agent.get(url)
    code = page.code
  rescue Mechanize::ResponseCodeError => e
    page = nil
    code = e.response_code
  end
  [page, code]
end

def show_user_agent(user_agent_hash)
  user_agent_hash.each_key do |key|
    puts "#{key}"
  end
end

DEFAULT_USER_AGENT = "Firefox33"

USER_AGENT = {
  "IE9" => "Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)",
  "Firefox33" => "Mozilla/5.0 (Windows NT 6.1; rv:33.0) Gecko/20100101 Firefox/33.0"
}

options = {
  user_agent: USER_AGENT[DEFAULT_USER_AGENT],
  interval:   1
}

@option_parser = OptionParser.new do |opts|
  exec_name = File.basename($PROGRAM_NAME)
  opts.banner = "Link check program

Usage: ruby #{exec_name} [options] url...

"
  opts.on("-u", "--user-agent", "Set User-agent (default: #{DEFAULT_USER_AGENT})") do |user_agent|
    options[:user_agent] = USER_AGENT[user_agent]
  end

  opts.on("-i sec", "--interval", "Set request interval [sec] (default 1sec) ") do |interval|
    options[:interval] = interval.to_i
  end

  opts.on("", "--show-user-agent", "Show support user-agent") do |interval|
    show_user_agent(USER_AGENT)
    exit 1
  end

  opts.on("-h", "--help", "Show help") do
    usage
    exit 1
  end
end

@option_parser.parse!

if options[:file_name] && ARGV.size > 0
  puts "If you specify a file, URL can not be specified."
  exit 1
end

if ARGV.size == 0
  puts "Specify URL"
  exit 1
end

url = ARGV[0]
user_agent = options[:user_agent]

scheme, authority = get_scheme_authority(url)

if scheme.nil? || authority.nil?
  puts "URL Malformed."
  exit 1
end

agent = Mechanize.new
agent.user_agent = user_agent
page, code = get_page_and_code(agent, url)

mark = code == "200" ? "" : "*"

puts "#{mark}\t#{code}\troot\t#{url}"

if code != "200"
  puts "Can not get a root page."
  exit 1
end

original_links = []

page.links.each do |link|
  original_links << link.href
end

links = original_links.sort

uniq_link_items = uniq(links)

uniq_link_items.each do |item|
  url = item[0]
  count = item[1]

  if url =~ /^\// || url =~ %r[^https?://#{authority}/]
    page, code = get_page_and_code(agent, url)
    mark = code == "200" ? "" : "*"
    print "#{mark}\t#{code}\t"
  else
    print "\t\t"
  end

  puts "#{count}\t#{url}"

  sleep options[:interval]
end
