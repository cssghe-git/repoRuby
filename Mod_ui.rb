#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true
#
=begin
    DOC     Function:   ?
    DOC     Call:       ruby ? --?
    DOC     Build:      260206-1000
    DOC     Version:    1.1.1
        Bugs:       ?

=end

begin
  require "cli/ui"
  CLI::UI::StdoutRouter.enable
#  CLI::UI::Frame.divider('═')
rescue LoadError
end

    module  ModeleUI
    #***************

    def self.ui_step(title)
    #---------------
        if defined?(CLI::UI)
            CLI::UI::Frame.open(title) { yield }
        else
            puts "==== #{title} ===="
            yield
        end
    end

    def self.ui_info(message)
    #---------------
        if defined?(CLI::UI)
            CLI::UI::fmt("{{info}}#{message}{{/info}}")
        else
            message
        end
    end

    def self.ui_ok(message)
    #-------------
        if defined?(CLI::UI)
            CLI::UI::fmt("{{green:✓}} #{message}")
        else
            message
        end
    end

    def self.ui_spin(title)
    #---------------
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = nil
        if defined?(CLI::UI)
            CLI::UI::Spinner.spin(title) do
                result = yield
            end
        else
            puts "#{title}..."
            result = yield
        end
        elapsed_sec = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(2)
        puts ui_ok("#{title} terminé en #{elapsed_sec}s")
        result
    end
end #<Modele>