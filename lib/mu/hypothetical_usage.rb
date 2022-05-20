


## In scryglass:
module Scryglass
  class Config
    # def config_ui
    #   mu_session = Mu::Session.new(
    #                  self,
    #                  optional_save_lambda: ->(config) { config.validate! }
    #                )
    #   mu_session.load_instance_variables
    #
    #   mu_session.run_mu_ui
    # end
    #
    # def config_ui
    #   self.mu!(
    #     {
    #       :@cursor_tracking => {
    #         type: :dropdown,
    #         options: [['option 1', :option_1], ['The Second Option', :the_second_option], ['Wozers how many are there', :wowzers]],
    #       },
    #       :@include_empty_associations => { type: :boolean },
    #       :@include_through_associations => { type: :boolean },
    #       :@include_scoped_associations => { type: :boolean },
    #       :@dot_coloring => { type: :boolean },
    #     }
    #   )
    # end

    # For Mu
    def mu_attribute_interpreter
      {
        :@cursor_tracking => {
          type: :dropdown,
          options: [
            { string: 'option 1',
              object: :option_1 },
            { string: 'The Second Option',
              object: :the_second_option },
            { string: 'Wozers how many are there',
              object: :wowzers },
          ],
        },
        :@lenses => {
          type: :checklist,
          # options: [], # Optional for checklists?
          options: Scryglass::Config::LENSES,
        },
        :@include_empty_associations => { type: :boolean },
        :@include_through_associations => { type: :boolean },
        :@include_scoped_associations => { type: :boolean },
        :@show_association_types => { type: :boolean },
        # :@dot_coloring => { type: :boolean },
        :@dot_coloring => { type: :trilean }, # temporary, testing
      }
    end
  end
end
