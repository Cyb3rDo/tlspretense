module SSLTest
  # Handles a list of arguments, and uses the arguments to run a sequence of tests.
  class Runner

    attr_reader :results

    DEFAULT_OPTS = {
        :pause => false,
        :config => Config::DEFAULT,
        :action => :runtests,
      }

    def parse_args(args)
      options = DEFAULT_OPTS.dup

      opts = OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} [options] [tests to run]"

        opts.on("-p","--[no-]pause", "Pause between tests") do |v|
          options[:pause] = true
        end

        opts.on("-c", "--config path/to/config.yml",
                "Specify a custom config.yml file",
                "  (Default: #{DEFAULT_OPTS[:config]})") do |confname|
          options[:config] = confname
        end

        opts.on("-l","--list", "List all tests (or those specified on the command line") do |v|
          options[:action] = :list
        end

      end

      args = args.dup
      opts.parse!(args)
      return [options, args]
    end

    def initialize(args, stdin, stdout)
      @options, args = parse_args(args)
      @test_list = args
      @stdin = stdin
      @stdout = stdout

      @config = Config.new @options
      @cert_manager = CertificateManager.new(@config.certs)

      @report = SSLTestReport.new
    end

    def run
      case @config.action
      when :list
        @stdout.puts "These are the test I will perform and their descriptions:"
        @stdout.puts ''
        @config.tests(@test_list.empty? ? nil : @test_list).each do |test|
          display_test test
        end
      when :runtests
        @report = SSLTestReport.new
        first = true
        @config.tests( @test_list.empty? ? nil : @test_list).each do |test|
          pause if @config.pause? and not first
          run_test test
          first = false
        end
        @report.print_results(@stdout)
      else
        raise "Unknown action: #{opts[:action]}"
      end
    end

    # Runs a test based on the test description.
    def run_test(test)
      SSLTestCase.new(@config, @cert_manager, @report, test).run
    end

    def display_test(test)
      @stdout.printf "%s: %s\n", test['alias'], test['name']
      @stdout.printf "  %s\n", test['certchain'].inspect
      @stdout.puts ''
    end

    def pause
      @stdout.puts "Press Enter to continue."
      @stdin.gets
    end

  end
end
