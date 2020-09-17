# frozen_string_literal: true

## Prog is a simple progress bar for tracking one or more nested or simultaneous
##   processes. Tasks fit evenly and dynamically into a Pipe, which can then
##   be displayed at a chosen width.
module Prog
  class Pipe
    attr_accessor :tasks
    attr_accessor :highest_count

    def initialize
      self.tasks = []
      self.highest_count = 0
    end

    def to_s(length: $stdout.winsize[1])
      return ' ' * length if tasks.count.zero?

      unused_length = length
      self.highest_count = [highest_count, tasks.count].max

      ## Set up the first barrier
      display_string = +'|'
      unused_length -= 1

      ## Get a first pass at equal task length
      # first_pass_task_length = unused_length/working_tasks.count
      first_pass_task_length = unused_length / highest_count
      if first_pass_task_length < 2
        raise "Prog::Pipe length (#{length}) too small to " \
              "fit all tasks (#{tasks.count})"
      end
      tasks.each do |task|
        task.working_length = first_pass_task_length
      end

      ## Distribute the remaining space evenly among the first n tasks
      remaining_space = unused_length - (first_pass_task_length * highest_count)
      tasks[0...remaining_space].each { |task| task.working_length += 1 }

      tasks.each do |task|
        display_string << task.to_s
      end
      display_string.ljust(length, ' ')
    end

    def <<(task)
      tasks << task
      task.pipe = self
      task.force_finish if task.max_count.zero?
    end
  end

  class Task
    attr_accessor :pipe, :max_count, :current_count
    attr_accessor :working_length

    def initialize(max_count:)
      self.max_count = max_count
      self.current_count = 0
      self.working_length = nil # (Only set by Prog::Pipe)
    end

    def tick(number_of_ticks = 1)
      self.current_count += number_of_ticks

      force_finish if current_count >= max_count
    end

    def force_finish
      pipe.tasks.delete(self)
      pipe.highest_count = 0 if pipe.tasks.empty?
    end

    def to_s
      progress_ratio = current_count / max_count.to_f

      unused_length = working_length
      display_string = +'|' # (not frozen)
      unused_length -= 1

      filled_cells = (unused_length * progress_ratio).floor
      fill_bar = ('=' * filled_cells).ljust(unused_length, ' ')
      display_string.prepend(fill_bar)

      display_string
    end
  end
end
