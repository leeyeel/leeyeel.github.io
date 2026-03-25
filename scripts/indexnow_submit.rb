#!/usr/bin/env ruby
# frozen_string_literal: true

require 'date'
require 'json'
require 'net/http'
require 'optparse'
require 'set'
require 'shellwords'
require 'uri'
require 'yaml'

class IndexNowSubmitter
  SITEWIDE_PATTERNS = [
    /\A_config\.yml\z/,
    /\AGemfile\z/,
    /\A_layouts\//,
    /\A_includes\//,
    /\A_sass\//
  ].freeze

  ROUTABLE_GLOBS = [
    '_posts/**/*.{md,markdown,html}',
    'page/**/*.{md,markdown,html}',
    '*.html',
    '*.md',
    '*.markdown'
  ].freeze

  ROOT_CONTENT_EXCLUDES = %w[
    README.md
    OPTIMIZATION_SUMMARY.md
  ].freeze

  def initialize(options)
    @base_url = normalize_base_url(options.fetch(:base_url))
    @host = URI(@base_url).host
    @key_file = options.fetch(:key_file)
    @from_ref = normalize_ref(options[:from_ref])
    @to_ref = normalize_ref(options[:to_ref]) || 'HEAD'
    @full_scan = options[:full_scan]
    @dry_run = options[:dry_run]
    @verbose = options[:verbose]
    @wait_url_list_file = options[:wait_url_list_file]
    @key = File.read(@key_file, encoding: 'utf-8').strip
    @key_location = "#{@base_url}/#{File.basename(@key_file)}"
    @site_config = load_site_config
  end

  def run
    urls = submission_urls
    wait_urls = waitable_urls

    write_wait_url_list(wait_urls)

    if urls.empty?
      puts 'No routable content changes detected for IndexNow.'
      return
    end

    payload = {
      host: @host,
      key: @key,
      keyLocation: @key_location,
      urlList: urls.to_a.sort
    }

    if @dry_run
      puts JSON.pretty_generate(payload)
      return
    end

    response = post_payload(payload)
    puts "IndexNow response: #{response.code} #{response.message}"
    puts response.body unless response.body.to_s.empty?
    raise "IndexNow submission failed with status #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  end

  private

  def submission_urls
    return full_site_urls if @full_scan || sitewide_change?

    urls = Set.new
    diff_entries.each do |entry|
      case entry[:status]
      when 'A', 'M'
        add_url(urls, entry[:path], ref: @to_ref)
      when 'D'
        add_url(urls, entry[:path], ref: @from_ref)
      when 'R'
        add_url(urls, entry[:old_path], ref: @from_ref)
        add_url(urls, entry[:path], ref: @to_ref)
      end
    end
    urls
  end

  def waitable_urls
    return full_site_urls if @full_scan || sitewide_change?

    urls = Set.new
    diff_entries.each do |entry|
      case entry[:status]
      when 'A', 'M'
        add_url(urls, entry[:path], ref: @to_ref)
      when 'R'
        add_url(urls, entry[:path], ref: @to_ref)
      end
    end
    urls
  end

  def full_site_urls
    urls = Set.new
    routable_files.each do |path|
      add_url(urls, path, ref: @to_ref)
    end
    urls
  end

  def sitewide_change?
    diff_entries.any? do |entry|
      [entry[:path], entry[:old_path]].compact.any? do |path|
        SITEWIDE_PATTERNS.any? { |pattern| pattern.match?(path) }
      end
    end
  end

  def diff_entries
    @diff_entries ||= begin
      output =
        if @from_ref
          run_cmd('git', 'diff', '--name-status', '--find-renames', @from_ref, @to_ref)
        else
          run_cmd('git', 'show', '--pretty=format:', '--name-status', '--find-renames', @to_ref)
        end

      output.lines.filter_map do |line|
        line = line.strip
        next if line.empty?

        parts = line.split("\t")
        code = parts[0][0]
        case code
        when 'A', 'M', 'D'
          { status: code, path: parts[1] }
        when 'R'
          { status: 'R', old_path: parts[1], path: parts[2] }
        end
      end
    end
  end

  def routable_files
    ROUTABLE_GLOBS.flat_map { |glob| Dir.glob(glob, File::FNM_EXTGLOB) }
      .uniq
      .sort
      .select { |path| routable_candidate?(path) }
  end

  def routable_candidate?(path)
    return false unless File.file?(path)
    return false if path.start_with?('_drafts/', '_layouts/', '_includes/')
    return false if ROOT_CONTENT_EXCLUDES.include?(path)

    true
  end

  def add_url(urls, path, ref:)
    return unless path

    url_path = public_path_for(path, ref: ref)
    return unless url_path

    urls << "#{@base_url}#{url_path}"
  end

  def public_path_for(path, ref:)
    content = read_file_at_ref(path, ref)
    if post_path?(path)
      front_matter, _, raw_front_matter = split_front_matter(content)
      permalink = front_matter['permalink']
      return normalize_public_path(permalink) if permalink

      return post_permalink(path, front_matter, raw_front_matter)
    end

    return '/' if path == 'index.html'
    return nil unless page_path?(path)

    front_matter, = split_front_matter(content)
    permalink = front_matter['permalink']
    return normalize_public_path(permalink) if permalink
    return nil unless content&.start_with?("---\n")

    fallback_page_path(path)
  rescue StandardError => e
    warn "Skipping #{path}: #{e.message}" if @verbose
    nil
  end

  def post_path?(path)
    path.start_with?('_posts/')
  end

  def page_path?(path)
    path.start_with?('page/') || root_content_page?(path)
  end

  def root_content_page?(path)
    !path.include?('/') && path.match?(/\A.+\.(html|md|markdown)\z/)
  end

  def fallback_page_path(path)
    relative = path.sub(/\Apage\//, '')
    directory = File.dirname(relative)
    basename = File.basename(relative, '.*')
    if basename == 'index'
      directory == '.' ? '/' : "/#{directory}/"
    else
      directory == '.' ? "/#{basename}/" : "/#{directory}/#{basename}/"
    end
  end

  def post_permalink(path, front_matter, raw_front_matter)
    basename = File.basename(path, File.extname(path))
    match = basename.match(/\A(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})-(?<slug>.+)\z/)
    raise "Unrecognized post filename format: #{path}" unless match

    date = extract_date_parts(front_matter['date'], raw_front_matter)
    year = date[:year] || match[:year]
    month = date[:month] || match[:month]
    day = date[:day] || match[:day]
    slug = match[:slug]
    template = @site_config['permalink'].to_s
    template = '/:year/:month/:day/:title/' if template.empty?

    output = template.dup
    output.gsub!(':year', year)
    output.gsub!(':month', month)
    output.gsub!(':day', day)
    output.gsub!(':title', slug)
    output.gsub!(':output_ext', '.html')
    normalize_public_path(output)
  end

  def extract_date_parts(value, raw_front_matter = nil)
    if raw_front_matter
      match = raw_front_matter.match(/^\s*date:\s*(?<value>.+?)\s*$/)
      if match
        parsed = extract_date_parts(match[:value].delete_prefix('"').delete_suffix('"').delete_prefix("'").delete_suffix("'"))
        return parsed unless parsed.empty?
      end
    end

    case value
    when Time, DateTime
      { year: value.strftime('%Y'), month: value.strftime('%m'), day: value.strftime('%d') }
    when Date
      { year: value.strftime('%Y'), month: value.strftime('%m'), day: value.strftime('%d') }
    when String
      match = value.match(/\A(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})/)
      match ? { year: match[:year], month: match[:month], day: match[:day] } : {}
    else
      {}
    end
  end

  def split_front_matter(content)
    return [{}, content, nil] unless content&.start_with?("---\n")

    parts = content.split(/^---\s*$\n?/, 3)
    raw_front_matter = parts[1]
    front_matter = YAML.safe_load(raw_front_matter, permitted_classes: [Date, Time], aliases: true) || {}
    [front_matter, parts[2], raw_front_matter]
  end

  def read_file_at_ref(path, ref)
    if ref.nil? || ref == 'HEAD'
      return File.read(path, encoding: 'utf-8') if File.exist?(path)

      return nil
    end

    run_cmd('git', 'show', "#{ref}:#{path}")
  rescue RuntimeError
    return File.read(path, encoding: 'utf-8') if File.exist?(path)

    nil
  end

  def load_site_config
    return {} unless File.exist?('_config.yml')

    YAML.safe_load(File.read('_config.yml', encoding: 'utf-8'), aliases: true) || {}
  rescue StandardError
    {}
  end

  def normalize_public_path(path)
    normalized = path.start_with?('/') ? path : "/#{path}"
    normalized = "#{normalized}/" unless normalized.end_with?('/', '.html')
    normalized
  end

  def normalize_base_url(url)
    url.chomp('/')
  end

  def normalize_ref(ref)
    return nil if ref.nil? || ref.empty?
    return nil if ref.match?(/\A0+\z/)

    ref
  end

  def write_wait_url_list(urls)
    return unless @wait_url_list_file

    File.write(@wait_url_list_file, urls.to_a.sort.join("\n"))
    File.write(@wait_url_list_file, "#{File.read(@wait_url_list_file)}\n") unless urls.empty?
  end

  def post_payload(payload)
    uri = URI('https://api.indexnow.org/indexnow')
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json; charset=utf-8'
    request.body = JSON.generate(payload)

    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
  end

  def run_cmd(*args)
    command = args.map { |arg| Shellwords.escape(arg) }.join(' ')
    output = `#{command}`
    raise "Command failed: #{command}" unless $?.success?

    output
  end
end

options = {
  base_url: ENV['INDEXNOW_BASE_URL'] || 'https://blog.whatsroot.xyz',
  key_file: ENV['INDEXNOW_KEY_FILE'] || 'c0b8a0805b6846729f5d0e69605f44c6.txt',
  from_ref: ENV['INDEXNOW_FROM_REF'],
  to_ref: ENV['INDEXNOW_TO_REF'] || 'HEAD',
  full_scan: false,
  dry_run: false,
  verbose: false,
  wait_url_list_file: nil
}

OptionParser.new do |parser|
  parser.on('--base-url URL') { |value| options[:base_url] = value }
  parser.on('--key-file PATH') { |value| options[:key_file] = value }
  parser.on('--from REF') { |value| options[:from_ref] = value }
  parser.on('--to REF') { |value| options[:to_ref] = value }
  parser.on('--full') { options[:full_scan] = true }
  parser.on('--dry-run') { options[:dry_run] = true }
  parser.on('--verbose') { options[:verbose] = true }
  parser.on('--write-wait-url-list PATH') { |value| options[:wait_url_list_file] = value }
end.parse!

IndexNowSubmitter.new(options).run
