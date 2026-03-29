# ruby
=begin

=end

# Requires
require 'thread'
require 'timeout'
require 'json'
require 'pp'
require 'optparse'
require 'rufus-scheduler'
require 'logger'

begin
  require "dotenv"; Dotenv.load('.env')
rescue LoadError
end

#
# Options
#********
    OPTIONS = {
        help: false,
        sleep: 10
    }
    OptionParser.new do |opts|
        opts.banner = "Usage: #{File.basename($0)} [options]"
        opts.on("-h", "--help", "Show this help message") { |v| OPTIONS[:help] = v }
        opts.on("-s","--sleep", "Sleep base") { |v| OPTIONS[:sleep] = v.to_i }
    end

#
# Logger
#*******
    LOG                 = Logger.new(STDOUT)
    LOG.level           = Logger::INFO
    LOG.datetime_format = '%H:%M:%S'

#
# Variables
#**********

    SCRIPTS = {
        #"key" => {
        #    name: "script1",
        #    path: "path/to/script1.rb",
        #    args: ["flag.?", ...] / nil,
        #    type: "auto" / "manual" / "interval",
        #    pid: nil,
        #    status: "stopped" / "running",
        #    time_start: "06:00:00",
        #    time_end: "18:00:00" / nil,
        #    days: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
        #    interval: n * OPTIONS[:sleep] seconds,
        #    time_last_run: Time.now
        #},

    }
    SCRFILE = "PrvScheduler.json"

# Functions
#**********

    def run_script(key)
    #+++++++++++++
    # Run script
    #
        # Checks
        script = SCRIPTS[key]
        return unless script
        return if script[:status] == "running"

        LOG.info("Running script: #{script[:name]}")

        # Build command
        cmd = "ruby #{script[:path]}"
        if script[:args]
            args2 = []
            args = script[:args]
            args.each do |arg|
                LOG.info("Processing argument: #{arg}")
                print "Sched>Enter value for #{arg}: ? "
                arg_value = gets.chomp
                args2.push("--#{arg} #{arg_value}")
            end
            cmd += " " + args2.join(" ")
        end

        # Run command
        begin
            pid = Process.spawn(cmd)
            Process.detach(pid)
            script[:pid] = pid
            script[:status] = "running"
            script[:time_last_run] = Time.now
            LOG.info("Script #{script[:name]} is running with PID #{pid}")
        rescue => e
            LOG.error("Failed to run script #{script[:name]}: #{e.message}")
        end
    end #<def>

    def stop_script(key)
    #++++++++++++++
    # Stop script
    #
        # Checks
        script = SCRIPTS[key]
        return unless script
        return if script[:status] == "stopped"

        LOG.info("Stopping script: #{script[:name]}")

        # Stop process
        begin
            Process.kill("TERM", script[:pid])
            script[:pid] = nil
            script[:status] = "stopped"
            LOG.info("Script #{script[:name]} has been stopped")
        rescue => e
            LOG.error("Failed to stop script #{script[:name]}: #{e.message}")
        end
    end #<def>

    def reset_script(key)
    #++++++++++++++
    # Reset script
    #
        SCRIPTS[key][:pid] = nil
        SCRIPTS[key][:status] = "stopped"
    end #<def>

    def check_scripts
    #++++++++++++++++
    # Check scripts
    #
        SCRIPTS.each do |key, script|
            if script[:type] == "auto"
                now = Time.now
                time_start = Time.parse(script[:time_start])
                time_end = script[:time_end] ? Time.parse(script[:time_end]) : nil
                days = script[:days].map { |d| Date::DAYNAMES.index(d) }
                if days.include?(now.wday) && now >= time_start && (time_end.nil? || now <= time_end)
                    run_script(key)
                else
                    stop_script(key)
                end
            elsif script[:type] == "interval"
                # Interval logic can be implemented here if needed
            end
        end
    end #<def>

    def load_scripts
    #++++++++++++++++
    # Load scripts from JSON file
    #
        if File.exist?(SCRFILE)
            file = File.read(SCRFILE)
            data = JSON.parse(file)
            data.each do |key, script|
                SCRIPTS[key] = {
                    name: script["name"],
                    path: script["path"],
                    args: script["args"],
                    type: script["type"],
                    pid: nil,
                    status: "stopped",
                    time_start: script["time_start"],
                    time_end: script["time_end"],
                    days: script["days"],
                    interval: script["interval"]
                }
            end
        end
    end #<def>

    def save_scripts
    #++++++++++++++++
    # Save scripts to JSON file
    #
        data = {}
        SCRIPTS.each do |key, script|
            data[key] = {
                name: script[:name],
                path: script[:path],
                args: script[:args],
                type: script[:type],
                time_start: script[:time_start],
                time_end: script[:time_end],
                days: script[:days],
                interval: script[:interval]
            }
        end
        File.write(SCRFILE, JSON.pretty_generate(data))
    end #<def>

    def add_script
    #++++++++++++
    # Add new script
    #
        print "Sched>Enter script name: ? "
        name = gets.chomp
        print "Sched>Enter script path: ? "
        path = gets.chomp
        print "Sched>Enter script type (auto/manual/interval): ? "
        type = gets.chomp
        args = nil
        if type == "auto"
            print "Sched>Enter time start (HH:MM:SS): ? "
            time_start = gets.chomp
            print "Sched>Enter time end (HH:MM:SS) or leave blank: ? "
            time_end = gets.chomp
            time_end = time_end.empty? ? nil : time_end
            print "Sched>Enter days (comma separated, e.g. Monday,Tuesday): ? "
            days = gets.chomp.split(",").map(&:strip)
        elsif type == "interval"
            print "Sched>Enter interval in seconds: ? "
            interval = gets.chomp.to_i
        end

        key = name.downcase.gsub(" ", "_")
        SCRIPTS[key] = {
            name: name,
            path: path,
            args: args,
            type: type,
            pid: nil,
            status: "stopped",
            time_start: time_start,
            time_end: time_end,
            days: days,
            interval: interval
        }
    end #<def>

    def list_scripts
    #++++++++++++
    # List all scripts
    #
        SCRIPTS.each do |key, script|
            LOG.info("Script: #{script[:name]}, Status: #{script[:status]}, Type: #{script[:type]}")
        end
    end #<def>

    def remove_script
    #+++++++++++++++
    # Remove script
    #
        print "Sched>Enter script name to remove: ? "
        name = gets.chomp
        key = name.downcase.gsub(" ", "_")
        if SCRIPTS[key]
            stop_script(key) if SCRIPTS[key][:status] == "running"
            SCRIPTS.delete(key)
            LOG.info("Script #{name} has been removed")
        else
            LOG.error("Script #{name} not found")
        end
    end #<def>

# Main
#*****
    LOG.info("Starting PrvScheduler...")
    LOG.info("-1- Load scripts")
    load_scripts

    LOG.info("-2- Start scheduler")
    scheduler = Rufus::Scheduler.new
    scheduler.every "#{OPTIONS[:sleep]}s" do
        check_scripts
    end

    LOG.info("-3- Entering main loop")
    loop do
        puts
        puts "Options: (1) Add Script, (2) List Scripts, (3) Remove Script, (4) Run Script, (5) Stop Script, (6) Reset Script, (7) Check Scripts, (9) Exit"
        print "Sched>Choose an option: ? "
        choice = gets.chomp.to_i
        case choice
        when 1
            add_script
            save_scripts
        when 2
            list_scripts
        when 3
            remove_script
            save_scripts
        when 4
            print "Sched>Enter script name to run: ? "
            name = gets.chomp
            key = name.downcase.gsub(" ", "_")
            run_script(key) if SCRIPTS[key][:type] == "manual"
        when 5
            print "Sched>Enter script name to stop: ? "
            name = gets.chomp
            key = name.downcase.gsub(" ", "_")
            stop_script(key) if SCRIPTS[key][:type] == "manual"
        when 6
            print "Sched>Enter script name to reset: ? "
            name = gets.chomp
            key = name.downcase.gsub(" ", "_")
            reset_script(key) if SCRIPTS[key]
        when 7
            LOG.info("Sched>Checking scripts running...")
            SCRIPTS.each do |key, script|
                LOG.info("Script: #{script[:name]}, Status: #{script[:status]}, Type: #{script[:type]}, Last Run: #{script[:time_last_run]}")   if script[:status] == "running"
            end
        when 9
            break
        else
            LOG.error("Invalid option")
        end
    end

    LOG.info("Exiting PrvScheduler...")
