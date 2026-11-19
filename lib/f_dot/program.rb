# frozen_string_literal: true

=begin

  program.rb

  f_dot program.

  created by i2097i

=end

module FDot
  module Based

    class Program
      attr_accessor :uuid
      attr_accessor :variables
      attr_accessor :instructions
      attr_accessor :history

      def initialize(state_uuid = nil)
        puts "#{self}.#{__method__}"
        self.uuid = state_uuid || FDot::Based.generate_uuid
        self.variables = {}
        self.instructions = {}
        self.history = {}

        generate_variables!
      end

      def generate_variables!
        return unless self.variables.empty?
        FDot::Based::TYPES.each_with_index{|b_type, b_type_index|
          FDot::Based::NUMBERS.each_with_index{|b_number, b_number_index|
            new_variable = FDot::Based::Variable.new(
              self.uuid,
              b_type,
              b_number_index
            )
            self.variables[new_variable.uuid] = new_variable
          }
        }

        FDot::Based.print_large_title!
        puts startup_notes

        # start a new program
        exit if :close_program == FDot::Based.tty_prompt_select(
          "press enter to continue",
          [{name: :start, value: :start}, {name: :close_program, value: :close_program}]
        )
      end

      def startup_notes
        [
          "welcome to f_dot. | f_dot is based. | this is a based f_dot program.\n",
          "interface description:\n",
          "based_variable:",
          "\tthe based variable is randomly chosen when the program starts.",
          "\tthe based variable is used as a checksum at the end of the program.",
          "compiler:",
          "\tthe compiler combines equal variables into instructions.",
          "\tthe compiler combines equal instructions.",
          "\tthe compiler runs in the processor domain.",
          "processor:",
          "\tthe processor processes the f_dot_queue of variables.",
          "\tthe processor domain is the root of the program.",
          "programmer:",
          "\tthe programmer is domain is a user-like domain that responds to user actions.",
          "\tthe programmer is distributed variables the same way as they are given to users.",
          "user:",
          "\tthe user is a human operating an FDot::Based unix system.",
          "\tthe user is only able to move instructions from the user domain to the processor domain.",
          "program operation:\n",
          "\t1) the user and programmer domains receive variables from the f_dot_queue.",
          "\t2) 11 variables are dequeued to both 3 times throughout the program.",
          "\t3) at the end of the program both domains receive 5 variables once.",
          "\t4) the program then calculates the based checksum.",
          "\t5) a new program starts.\n",
          "user usage:\n",
          "\t=> navigate to the user menu",
          "\t=> select a variable in the user menu to move it to the compiler.",
          "\n"
        ].join("\n")
      end

      def ready_to_deque?
        [:programmer, :user].map{|k| FDot.state[k].nil? ? [] : FDot.state[k][:variables] }.all?{|a| a.empty?}
      end

      def ready_to_based?
        compile_variables = compiler_contents[:variables]

        ready_to_deque? && (
          (FDot::Based::NUMBERS.count - 1) == compile_variables.count
        ) && !compile_variables.any?{|v_uuid|
          self.variables[v_uuid].ordinal == self.variables[FDot.state[:based_uuid]].ordinal
        }
      end

      # primary read of compiler contents
      def compiler_contents
        # a variable or instruction is considered inside of
        # compiler_contents if it is not in any of the
        # following domains:
        #
        #  => :based_variable
        #  => :f_dot_queue
        #  => :processor
        #
        # note => :based_variable is not strictly a domain
        #

        {
          variables: self.variables.select{|k, v|
            k != FDot.state[:based_uuid] &&
            !FDot.state[:f_dot_queue].include?(k) &&
            !FDot.state[:programmer][:variables].include?(k) &&
            !FDot.state[:user][:variables].include?(k) &&
            !self.instructions.any?{|i_uuid, i_instance| i_instance.variable_uuids.include?(k)}
          }.map{|k, v| k},
          instructions: self.instructions.select{|k, v|
            !FDot.state[:programmer][:instructions].include?(k) &&
            !FDot.state[:user][:instructions].include?(k)
          }.map{|k, v| k},
        }
      end

      # deal out one variable
      def move_next_variable_to(move_to_domain_key)
        return unless FDot.state[:f_dot_queue].any?

        # get the next var
        next_var = FDot.state[:program].variables[
          FDot.state[:f_dot_queue].delete_at(0)
        ]

        self.add_move_history(next_var, move_to_domain_key)
      end

      def build_space!
        initialize_space!

        f_dot_de_queue!

        check_for_based_conditions!
      end

      def add_combine_history(instance_one, instance_two)
        raise "cannot combine! #{instance_one.to_s} and #{instance_two.to_s}" unless [
          instance_one.domain,
          instance_two.domain
        ].uniq.first == FDot::DOMAINS[:processor]

        allowed_const_types = [
          FDot::Based::Instruction,
          FDot::Based::Variable
        ]

        const_one = instance_one.class
        const_two = instance_two.class

        allowed_intersection = (
          allowed_const_types & [const_one, const_two]
        )
        puts allowed_intersection
        unless allowed_intersection.all?{|c| allowed_const_types.map{|c| c.name}.include?(c.name)}
          raise "invalid const(s)! #{const_one}:#{const_two}"
        end
        puts "combining #{const_one.name} with #{const_two.name}" if FDot::Based::Processor.user_setting!(:show_history_logging)
        case const_one.name
        when FDot::Based::Instruction.name
          case const_two.name
          when FDot::Based::Instruction.name
            # combine instruction instance_one with instruction instance_two
            removed_instruction = instance_one.combine_with_instruction(instance_two)
            raise "failed to combine!" unless removed_instruction.variable_uuids.empty?
            self.compile!(instance_one.uuid)
          when FDot::Based::Variable.name
            # combine instruction instance_one with variable instance_two
            instance_one = instance_two.combine_with_instruction(instance_one)
            self.compile!(instance_one.uuid)
          end
        when FDot::Based::Variable.name
          case const_two.name
          when FDot::Based::Instruction.name
            # add variable instance_one to instruction instance_two
            instance_two = instance_one.combine_with_instruction(instance_two)
            self.compile!(instance_two.uuid)
          when FDot::Based::Variable.name
            # create new instruction and add it to history and processor instructions
            new_instruction = instance_one.combine_with_variable(instance_two)
            self.compile!(new_instruction.uuid)
          end
        end
      end

      def add_move_history(variable, move_to_domain_key)
        move_to_domain_key = move_to_domain_key.to_sym

        # remove variable uuid from current domain
        if variable.domain_key == :processor
          FDot.state[:f_dot_queue].delete(variable.uuid)
        else
          FDot.state[variable.domain_key][:variables].delete(variable.uuid)
        end

        # add the variable to domain
        if move_to_domain_key != :processor
          FDot.state[move_to_domain_key][:variables] << variable.uuid
        end

        # create a history entry
        history[variable.uuid] ||= []
        history[variable.uuid] << FDot::Based::History.create_variable_history!(
          variable,
          FDot::DOMAINS[move_to_domain_key]
        )
        puts history[variable.uuid].last.to_s if FDot::Based::Processor.user_setting!(:show_history_logging)

        self.compile!(variable.uuid)
      end

      def compile!(lineage_uuid)
        raise "invalid lineage_uuid" unless history.keys.include?(lineage_uuid)
        history_instance = history[lineage_uuid].last
        compile_instructions!(history_instance)
        compile_variables!(history_instance)
        FDot::Based::Processor.serialize_state!
      end

      def show_history_interface!
        history_menu_open = true
        while history_menu_open
          to_show_history_uuid = FDot::Based.tty_prompt_select(
            "which item do you want to view the history for?",
            [{name: :back, value: :back}] + self.history_menu_options
          )

          break if to_show_history_uuid == :back

          history_timestamp = FDot::Based.tty_prompt_select(
            "which record would you like to open?",
            [{name: :back, value: :back}] + self.history_menu_options_for(to_show_history_uuid)
          )

          next if history_timestamp == :back

          history_instance = self.history[to_show_history_uuid].select{|h| h.timestamp == history_timestamp}.first

          raise "invalid history_instance!" if history_instance.nil?

          history_instance.show_interface!
        end

      end

      def compute_serialized_state!
        serialized_instructions = {}
        self.instructions.keys.each{|k|
          serialized_instructions[k] = self.instructions[k].compute_serialized_state!
        }
        serialized_variables = {}
        self.variables.keys.each{|k|
          serialized_variables[k] = self.variables[k].compute_serialized_state!
        }
        serialized_history = {}
        self.history.keys.each{|k|
          serialized_history[k] = history[k].map{|h| h.compute_serialized_state!}
        }

        {
          uuid: self.uuid,
          instructions: serialized_instructions,
          variables: serialized_variables,
          history: serialized_history,
        }
      end

      private

      def history_menu_options_for(historical_uuid)
        self.history[historical_uuid].map{|history_instance|
          {name: history_instance.to_s, value: history_instance.timestamp}
        }
      end

      def history_menu_options
        all_history = []
        self.history.map{|historical_uuid, history_array|
          all_history += history_array || []
        }

        all_history.sort_by{|history_instance|
          history_instance.timestamp
        }.reverse.map{|h| {name: "#{h.timestamp}): #{h.historical_instance.to_s}", value: h.historical_instance.uuid }}
      end

      def issue_variables!
        self.variables.keys.shuffle
      end

      def initialize_space!
        return unless FDot.state[:f_dot_queue].empty? && FDot.state[:based_uuid].nil?

        FDot::DOMAINS.each{|domain, i|
          case domain
          when :processor
            FDot.state[:f_dot_queue] = self.issue_variables!
            FDot.state[:instructions] = []
          when :programmer, :user
            FDot.state[domain] = {}
            FDot.state[domain][:variables] = []
            FDot.state[domain][:instructions] = []
          end
        }

        based_variable = FDot.state[:program].variables[
          FDot.state[:f_dot_queue].delete_at(0)
        ]
        puts "the based variable is #{based_variable.to_s}"
        # based_variable sets the tone for the process
        FDot.state[:based_uuid] = based_variable.uuid
        # create a history entry for based_variable

        add_move_history(based_variable, based_variable.domain_key)
      end

      def check_for_based_conditions!
        return unless ready_to_based?

        puts "running based checksum"
        compile_variables = compiler_contents[:variables]
        (compile_variables + [FDot.state[:based_uuid]]).each{|v_uuid|
          variable = self.variables[v_uuid]
          ordinal_instruction = self.instructions.values.select{|v|
            v.ordinal == variable.ordinal
          }.first
          raise "checksum failed!" if ordinal_instruction.nil?
          variable.combine_with_instruction(ordinal_instruction)
        }

        compile_variables = compiler_contents[:variables]
        raise "based failed!" unless compile_variables.count == 0

        puts "#{self} checksum successful."
        puts "#{self.class.name} completed."
        FDot.state[:completed_programs][self.uuid] = self

        puts "listing completed programs:"
        puts FDot.state[:completed_programs]

        FDot.state[:based_uuid] = nil
        FDot.state[:program] = FDot::Based::Program.new
      end

      def f_dot_de_queue!
        return unless !FDot.state[:f_dot_queue].empty? && ready_to_deque?

        # assign variables to programmer and user domains
        FDot::Based::NUMBERS.each{|n|
          [:programmer, :user].each{|k|
            move_next_variable_to(k)
          }
        }
      end

      def compile_variables!(history_instance)
        if history_instance.to_domain == FDot::DOMAINS[:processor]
          if FDot::Based::Processor.user_setting!(:auto_compile_enabled)
            while get_combinable_variables.any?
              combinable_variables = get_combinable_variables
              to_combine_instance = combinable_variables.first

              with_instance = get_variables_combinable_with(to_combine_instance.uuid).first
              add_combine_history(to_combine_instance, with_instance)
            end
          else
            # manually compile
            while get_combinable_variables.any?
              puts JSON.pretty_generate(get_combinable_variables)
              # prompt user to choose an instruction to combine
              to_combine_variable_uuid = FDot::Based.tty_prompt_select(
                "combinable_variables: ",
                get_combinable_variables.map{|variable_instance|
                  {name: variable_instance.to_s, value: variable_instance.uuid}
                }
              )
              to_combine_instance = self.variables[to_combine_variable_uuid]
              raise "invalid to_combine_instance!" if to_combine_instance.nil?

              puts "listing variables combinable with #{to_combine_instance.to_s}..."
              with_variable_uuid = FDot::Based.tty_prompt_select(
                "combine #{to_combine_instance.to_s} with?",
                get_variables_combinable_with(to_combine_variable_uuid).map{|variable_instance|
                  {name: variable_instance.to_s, value: variable_instance.uuid}
                }
              )
              with_instance = self.variables[with_variable_uuid]

              add_combine_history(to_combine_instance, with_instance)
            end
          end
        end
      end

      def compile_instructions!(history_instance)
        while get_combinable_instructions.any?
          if FDot::Based::Processor.user_setting!(:auto_compile_enabled)
            while get_combinable_instructions.any?
              combinable_instructions = get_combinable_instructions
              to_combine_instance = combinable_instructions.first
              with_instance = get_instructions_combinable_with(to_combine_instance.uuid).first
              add_combine_history(to_combine_instance, with_instance)
            end
          else
            # manually compile
            puts "#{__method__}"
            puts "listing instructions to compile..."
            to_combine_instruction_uuid = FDot::Based.tty_prompt_select(
              "combinable_instructions: ",
              get_combinable_instructions.map{|instruction_instance|
                {name: instruction_instance.to_s, value: instruction_instance.uuid}
              }
            )
            to_combine_instance = self.instructions[to_combine_instruction_uuid]
            raise "invalid to_combine_instance!" if to_combine_instance.nil?

            puts "listing instructions combinable with #{to_combine_instance.to_s}..."
            with_instruction_uuid = FDot::Based.tty_prompt_select(
              "combine #{to_combine_instance.to_s} with?",
              get_instructions_combinable_with(to_combine_instruction_uuid).map{|instruction_instance|
                {name: instruction_instance.to_s, value: instruction_instance.uuid}
              }
            )
            with_instance = self.instructions[with_instruction_uuid]

            add_combine_history(to_combine_instance, with_instance)
          end
        end
      end

      def get_combinable_instructions
        compiler_contents[:instructions].select{|i_uuid|
          get_instructions_combinable_with(i_uuid).any?
        }.map{|i_uuid| self.instructions[i_uuid]}
      end

      def get_combinable_variables
        compiler_contents[:variables].select{|v_uuid|
          get_variables_combinable_with(v_uuid).any?
        }.map{|v_uuid| self.variables[v_uuid]}
      end

      def get_instructions_combinable_with(i1_uuid)
        compiler_contents[:instructions].select{|i2_uuid|
          i1_uuid != i2_uuid &&
          self.instructions[i1_uuid].ordinal == self.instructions[i2_uuid].ordinal
        }.map{|u| self.instructions[u]}
      end

      def get_variables_combinable_with(v1_uuid)
        compiler_contents[:variables].select{|v2_uuid|
          v1_uuid != v2_uuid &&
          self.variables[v1_uuid].ordinal == self.variables[v2_uuid].ordinal
        }.map{|u| self.variables[u]}
      end

    end
  end
end