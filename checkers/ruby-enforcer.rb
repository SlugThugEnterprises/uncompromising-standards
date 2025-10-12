#!/usr/bin/env ruby
# Ruby Code Enforcer - Uncompromising Standards
# "Code so good you could trust it with your friend's mom's life"

RED = "\033[0;31m"
YELLOW = "\033[1;33m"
GREEN = "\033[0;32m"
NC = "\033[0m"

$critical = 0
$errors = 0
$warnings = 0

CRITICAL_PATTERNS = {
  bare_rescue: /rescue\s*$/,
  todo: /(TODO|FIXME|HACK|XXX|TEMP|WIP|PLACEHOLDER)/,
  debug_binding: /binding\.(pry|irb)/
}

def check_file(file_path)
  unless File.exist?(file_path)
    puts "Error: File not found: #{file_path}"
    exit 1
  end

  lines = File.readlines(file_path)

  puts "🔍 Checking Ruby file: #{file_path}"
  puts "━" * 60

  # Check file length
  if lines.length > 200
    puts "#{RED}🚨 CRITICAL#{NC}: File exceeds 200 lines"
    puts "   File: #{file_path}"
    puts "   Lines: #{lines.length} (limit: 200)"
    $critical += 1
  end

  # Check patterns
  CRITICAL_PATTERNS.each do |name, pattern|
    matches = []
    lines.each_with_index do |line, i|
      matches << i + 1 if line =~ pattern
    end

    unless matches.empty?
      puts "#{RED}🚨 CRITICAL#{NC}: No #{name} allowed"
      puts "   File: #{file_path}"
      puts "   Lines: #{matches.join(',')}"
      $critical += 1
    end
  end

  # Check puts outside main/tests
  is_test = file_path.include?('_test.rb') || file_path.include?('/test_')
  unless is_test || file_path.end_with?('main.rb')
    puts_lines = []
    lines.each_with_index do |line, i|
      puts_lines << i + 1 if line =~ /\bputs\s/
    end

    unless puts_lines.empty?
      puts "#{RED}❌ ERROR#{NC}: puts should only be in main.rb or tests"
      puts "   File: #{file_path}"
      puts "   Lines: #{puts_lines.join(',')}"
      puts "   Use proper logging (Logger)"
      $errors += 1
    end
  end

  puts "━" * 60
  puts "📊 Summary:"
  puts "   🚨 Critical: #{$critical}"
  puts "   ❌ Errors: #{$errors}"
  puts "   ⚠️  Warnings: #{$warnings}"

  if $critical > 0
    puts "#{RED}❌ Check FAILED - fix critical issues#{NC}"
    exit 1
  else
    puts "#{GREEN}✅ Check passed!#{NC}"
    exit 0
  end
end

if ARGV.empty?
  puts "Usage: ruby-enforcer.rb <file.rb>"
  exit 1
end

check_file(ARGV[0])
