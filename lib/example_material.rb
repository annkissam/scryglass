# frozen_string_literal: true

## Purely for use by Scryglass.demo_hash
class ScryExampleClass
  attr_accessor :instance_variable_1, :instance_variable_2, :instance_variable_3, :instance_variable_4

  def initialize
    self.instance_variable_1 = nil
    self.instance_variable_2 = true
    self.instance_variable_3 = {:test => true, :not_test => false}
    self.instance_variable_4 = 'Scrying is fun!'
  end
end

module Scryglass
  def self.test_hash
    {
      :move_into_this_sub_item_with_down_arrow => "I'm just a string",
      :disclaimer => 'This giant playground object is still no substitute for just pressing `?`...',
      :an_empty_array => [],
      :an_array_you_can_open_with_right_arrow => [
        1,
        1.0,
        'You can close this array, anywhere here, with left arrow',
        :an_empty_hash => {},
        :some_more_advanced_stuff => {
          'What about lens view?' => [
            "I'm a string, but you can prove it by pressing spacebar to toggle lens view",
            "There's lots to do with lens view, but the help screens ('?') are really best."
          ],
          'What is my cursor telling me about this Range object?' => (1...12),
          nil => "this line is so long you should use the w/a/s/d ('d' in particular) to see more. If you can see the whole line all at once, your text/screen ratio might need some balancing..." * 10,
          [1,2,3] => "Can't expand/collapse keys, sorry...",
          Scryglass::ViewWrapper.new('the actual string', string: 'This key appears differently in the tree view!') => Scryglass::ViewWrapper.new(24601, string: 'So do this integer!'),
          "A lambda" => ->(o) { puts o.inspect.upcase.reverse },
          "\n\n\n" => "If you want to know what that lambda does, move your cursor to it, press ENTER, and it will be returned to your console for you to play with!",
          'Allll the coolest stuff' => [
            Scryglass::ViewWrapper.new('TODO add link', string: '...Is really in the help screens (`?`) and the README. Press spacebar for README link in lens view'),
          ],
          :delicious_data => {
            :whoa_now => ([1]*800).map { rand(2) }.insert($stdout.winsize.first, 'Press zero to reset view position, then again to reset cursor there!'),
            999 => {
            4.1 => [4,1],
            5.1 => [5,1],
            6.1 => [6,1],
            7.1 => [7,1],
            8.1 => [8,1],
            9.1 => [9,1],
            0.1 => [0,1],
            1.1 => [1,1],
          },
            Array => [1,2, [1,2,[3]], [3, 88, [99, 100]], 0],
            'Some test classes with instance variables' => [
              ScryExampleClass.new,
              ScryExampleClass.new,
              ScryExampleClass.new,
              ScryExampleClass.new,
            ],
          },
        },
      ],
    }
  end

  def self.demo_hash
    {
      :time => Time.now,
      :temperature => 'Just right',
      :data => [
        [
          ScryExampleClass.new,
          ScryExampleClass.new,
        ],
        [
          ScryExampleClass.new,
          ScryExampleClass.new,
        ],
        [
          ScryExampleClass.new,
          ScryExampleClass.new,
        ],
        [
          ScryExampleClass.new,
          ScryExampleClass.new,
        ],
        [
          ScryExampleClass.new,
          ScryExampleClass.new,
        ],
        [
          ScryExampleClass.new,
          ScryExampleClass.new,
        ],
      ]
    }
  end
end
