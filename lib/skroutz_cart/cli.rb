require_relative 'client'
require_relative 'cart_runner'

module SkroutzCart
  module CLI
    COOKIE_FILE = File.join(Dir.pwd, 'cookie.txt')

    def self.parse_args(argv = ARGV)
      options = {}

      options[:cookie] = File.read(COOKIE_FILE).strip if File.exist?(COOKIE_FILE)

      argv.each_with_index do |arg, i|
        case arg
        when '--cookie', '-c'
          options[:cookie] = argv[i + 1]
        when '--cookie-file', '-cf'
          file = argv[i + 1]
          unless file && File.exist?(file)
            puts "Error: cookie file not found: #{file}"
            exit 1
          end
          options[:cookie] = File.read(file).strip
        when '--algorithm', '-a'
          val = argv[i + 1]&.downcase
          unless %w[dp bnb].include?(val)
            puts "Error: --algorithm must be 'dp' or 'bnb'"
            exit 1
          end
          options[:algorithm] = val.to_sym
        when '--yes', '-y'
          options[:confirm] = true
        when '--no', '-n'
          options[:confirm] = false
        when '--verbose', '-v'
          options[:verbose] = true
        when '--help', '-h'
          print_help
          exit 0
        end
      end

      options
    end

    def self.print_help
      puts <<~HELP
        Usage: ruby skroutz_cart.rb [options]

        Options:
          -c, --cookie STRING        Cookie string (required)
          -cf, --cookie-file FILE    File containing cookie string
          -a, --algorithm dp|bnb     Optimisation algorithm (default: dp)
          -y, --yes                  Automatically confirm adding to cart
          -n, --no                   Automatically decline adding to cart
          -v, --verbose              Verbose output
          -h, --help                 Show this help

        Example:
          ruby skroutz_cart.rb -c "_helmet_couch=...; cf_clearance=..."
          ruby skroutz_cart.rb -cf cookie.txt
          ruby skroutz_cart.rb -c "..." --yes
          ruby skroutz_cart.rb -c "..." --algorithm bnb
      HELP
    end

    def self.run(argv = ARGV)
      options = parse_args(argv)

      unless options[:cookie]
        puts 'Error: --cookie or --cookie-file is required'
        puts 'Run with --help for usage'
        exit 1
      end

      client = Client.new(options[:cookie])
      CartRunner.find_cheapest(client, verbose: options[:verbose], confirm: options[:confirm],
                                       algorithm: options[:algorithm])
    end
  end
end
