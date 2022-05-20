# frozen_string_literal: true

## TODO:
# ...
# - (DONE) only save staged changes when hitting a specific 'save' key!
# - (DONE) catch and show eval errors, and disallow saving if any errored
# - (DONE) maybe maintain session attached to object, after saving or maybe quitting?
# - (DONE) "Treat As ____" functionality!
# - (DONE) Be able to specify dropdown of valid options?
# - (DONE) Be able to specify array of items that can be checked/unchecked?
# - (DONE) shorten a memoized string for inspected objects in main view... or run the view inspect in a clip block like scryglass has
# ...
# - maybe 'r' to reset value
# - control the eval binding :O (I guess Done?)
# - catch and show attribute save errors?
# - catch and show final save errors?
# - AR attributes :O
# - truly consider having this just be a thing scryglass can do? Like, modifying and then save those changes?
# - and/or just consider moving some more view stuff from scryglass and mu to hexes
# - visual indicator -- little label -- about field type (dropdown, checklist, boolean)
# - special key to "interact"(?) as opposed to REPLACE. Like, interact could toggle booleans, open dropdowns, etc. Or maybe this is what ENTER should do?
# - Perhaps, after save, re-get each value from the object?
# - full save lambda! test with config
# - maybe have the session stay on that object...? Like, original checklist options would still be there? pros and cons?
# - looped scrolling on main menu?
# - should Mu::Eval be its own subclass of attribute?



load 'mu/attribute.rb'
load 'mu/boolean.rb'
load 'mu/checklist.rb'
load 'mu/dropdown.rb'
load 'mu/hypothetical_usage.rb'
load 'mu/session.rb'
load 'mu/trilean.rb'

module Mu
  def self.add_kernel_method
    Kernel.module_eval do
      def mu!
        begin
          Hexes.stdout_rescue do
            mu_session = Mu::Session.new(self)
            # self.instance_variable_set(:@mu_session, mu_session)
            class << self
              attr_accessor :mu_session
            end
            self.mu_session = mu_session

            return mu_session.run_mu_ui
          end
        rescue => e # Here we ensure good visibility in case of errors
          screen_height, _screen_width = $stdout.winsize
          $stdout.write "\e[#{screen_height};1H\n" # (Moves console cursor to bottom left corner)
          # ^ TODO: Consider using STDOUT instead of $stdout
          raise e
        end
      end
    end
  end
end
