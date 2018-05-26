# coding: utf-8
require 'imap-filter'

include ImapFilter::DSL

module ImapFilter
  module Functionality
    STATUS = {messages: 'MESSAGES', recent: 'RECENT', unseen: 'UNSEEN'}
    ISTAT = STATUS.map{ |k, v| [v, k] }.to_h
    
    def self.show_imap_plan
      puts '====== Accounts'.light_yellow
      _accounts.each do |name, account|
        print " #{name}: ".light_green
        print account.to_s.light_blue
        puts
      end
      puts '====== Filters'.light_yellow
      _filters.each do |name, filter|
        print " #{name}: ".light_green
        print filter.to_s.light_blue
        puts          
      end
    end

    # List all mboxes of given account and their statuses
    
    def self.login_imap_accounts test: false
      puts "====== #{test ? 'Test' : 'Login'} Accounts".light_yellow
      _functional_accounts.each do |name, account|
        print "  #{name}...".light_white
        begin
          account._open_connection
          puts "SUCCESS, delim #{account.delim}".light_green          
          
          account.mbox_list.each do |mbox, (stat, attr)|
            print "  #{mbox}".light_blue
            print " #{stat}".light_red
            puts " #{attr}".light_cyan
          end unless _options[:verbose] < 2
        rescue => e
          puts "FAILED: #{e}".light_red
          exit unless test
        end
      end
    end

    def self.list_of_filters_to_run
      unless _options[:filters].nil?
        _options[:filters].map{ |f| f.to_sym }
      else
        _filters.keys
      end
    end

    # do the selection based on directives
    # then perform the actions on the set selected.
    # optimize for copy/moves that are to the same account.
    def self.run_filter filt
      f = FunctFilter.new _filters[filt]
      f.select_email
      
      unless _options[:verbose] < 1
        puts "====== Email to be processed by #{filt}".light_yellow
        f.subject_list.each do |subject|
          print '  ##'.yellow
          puts subject.light_blue
        end
      end

      if f && ! f.seq.empty?
        @matched_filters << f.dfilt.name
      end
      
      f.process_actions 
      f.acc.imap.expunge unless _options[:dryrun]
    end
    
    def self.execute_filters
      @matched_filters = Array.new

      #login_imap_accounts
      list_of_filters_to_run.each do |f|
        print "Running filter: ".light_white
        puts "#{f}".light_yellow
        run_filter f
      end

      self.annotate_source(ARGV[1], @matched_filters)
    end

    def self.annotate_source(path, filters)
      return if filters.empty?
      source = File.readlines(path)

      filters.each do |filter|
        line = source.find { |line| line.match(/filter.*:#{filter}/) }

        unless index = source.index(line)
          warn "~ #{filter} cannot be found."
          next
        end

        comment_line = "# Last match: #{Time.now.strftime('%-d/%-m/%Y at %H:%M')}.\n"
        index_diff = source[0..index].reverse.index { |line| line.match(/# Last match:/) || line.chomp.empty? }
        if source[index - index_diff].match(/# Last match:/)
          source[index - index_diff] = comment_line
        else
          source.insert(index, comment_line)
        end
      end

      #unless source.bytesize == 0
        File.open(path, 'w') do |file|
          file.puts(source.join)
        end
      #end
    end
    
    def self.run_filters filters
      show_imap_plan unless _options[:verbose] < 1
      if _options[:test]
        login_imap_accounts test: true
      else
        login_imap_accounts
        execute_filters
      end
    end
  end
end
