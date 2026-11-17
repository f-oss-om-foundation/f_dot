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

      def initialize
        self.uuid = FDot::Based.generate_uuid
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
        puts startup_notes
      end

      def startup_notes
        [
          "starting #{self.class.name}...",
          "there are #{self.variables.count} variables inside of this program.",
          "within the program you are able to work with the variables.",
          "the workspace is an in-memory runtime application that uses",
          "oss_om to store program state.",
          "the location of the value of a variable may be modified.",
          "a blank directory is required in user space for the program to run.",
          "this is called the f_dot_space_path.",
          "located at #{FDot::Based.f_dot_space_path}.",
          "program operational procedures:",
          "domain listing:",
          FDot::DOMAINS.keys.to_s,
          "\n",
          "\t:processor  domain is where the compiler compiles instructions.",
          "\t:programmer domain contains programmer variables and instructions",
          "\t:user       domain contains user variables and instructions",
          "\n",
          "the program runs when the user moves a variable to the compiler.",
          "once this happens, the programmer then moves a variable to the compiler.",
          "as variables are moved to the compiler, the compiler will automatically",
          "combine same-ordinal variables into a new instruction.",
          "instructions are compiled when the the user or programmer moves",
          "a variable to the compiler with an equal value to any variable or",
          "instruction already inside the compiler"
        ].join("\n")
      end

      def get_options_for_variable_uuid(variable_uuid)
        variable_instance = self.variables[variable_uuid]

        raise "invalid variable uuid! #{variable_uuid}" if variable_instance.nil?
        variable_domain_key = FDot::DOMAINS.keys.select{|k| FDot::DOMAINS[k] == variable_instance.domain}.first
        raise "cannot perform operations in the #{variable_domain_key}" unless variable_domain_key == :user

        [
          {name: :back, value: :back},
          {name: :move_to_compiler, value: :move_to_compiler}
        ]
      end

      def issue_variables!
        self.variables.keys.shuffle
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
        puts "todo: f_dot_queue is empty!"
        return unless FDot.state[:f_dot_queue].any?
        # get the next var
        next_var = FDot.state[:program].variables[
          FDot.state[:f_dot_queue].delete_at(0)
        ]

        self.add_move_history(next_var, move_to_domain_key)
      end

      def initialize_space!
        FDot::DOMAINS.each{|domain, i|
          case domain
          when :processor
            FDot.state[:f_dot_queue] ||= self.issue_variables!
            FDot.state[:instructions] ||= []
          when :programmer, :user
            FDot.state[domain] ||= {}
            FDot.state[domain][:variables] ||= []
            FDot.state[domain][:instructions] ||= []
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

      def build_space!
        working_directory = FDot::Based.f_dot_space_path

        initialize_space! if FDot.state[:f_dot_queue].nil?

        f_dot_de_queue!
      end

      def f_dot_de_queue!
        return unless [:programmer, :user].map{|k| FDot.state[k][:variables] }.all?{|a| a.empty?}
        # assign first round variables
        # to programmer and user domains
        FDot::Based::NUMBERS.each{|n|
          [:programmer, :user].each{|k|
            move_next_variable_to(k)
          }
        }
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
        case const_one.name
        when FDot::Based::Instruction.name
          case const_two.name
          when FDot::Based::Instruction.name
            puts "combining #{FDot::Based::Instruction.name} with #{FDot::Based::Instruction.name}"
            # todo: build this
            puts "FDot::Based::Instruction -> FDot::Based::Instruction"
            # def combine_with_instruction(to_combine_instruction)
            # end
            # todo: implement in variable class:

          when FDot::Based::Variable.name
            puts "combining #{FDot::Based::Instruction.name} with #{FDot::Based::Variable.name}"
            # todo: build this
            puts "FDot::Based::Instruction -> FDot::Based::Variable"

            # todo: implement in variable class:
            # def combine_with_variable(to_combine_variable)
            # end
          end
        when FDot::Based::Variable.name
          puts "here " * 111
          puts const_two.name
          case const_two.name
          when FDot::Based::Instruction.name
            puts "combining #{FDot::Based::Variable.name} with #{FDot::Based::Instruction.name}"
            puts "FDot::Based::Variable -> FDot::Based::Instruction"
            #
            instance_two = instance_one.combine_with_instruction(instance_two)
            self.compile!(instance_two.uuid)
          when FDot::Based::Variable.name
            puts "combining #{FDot::Based::Variable.name} with #{FDot::Based::Variable.name}"
            puts "FDot::Based::Variable -> FDot::Based::Variable"
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

        puts history[variable.uuid].last.to_s

        self.compile!(variable.uuid)
      end

      def compile!(lineage_uuid)
        raise "invalid lineage_uuid" unless history.keys.include?(lineage_uuid)
        history_instance = history[lineage_uuid].last
        compile_instructions!(history_instance)
        compile_variables!(history_instance)
      end

      private

      def compile_variables!(history_instance)
        if history_instance.to_domain == FDot::DOMAINS[:processor]
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

      def compile_instructions!(history_instance)
        while get_combinable_instructions.any?
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
          with_variable_uuid = FDot::Based.tty_prompt_select(
            "combine #{to_combine_instance.to_s} with?",
            get_instructions_combinable_with(to_combine_instruction_uuid).map{|instruction_instance|
              {name: instruction_instance.to_s, value: instruction_instance.uuid}
            }
          )
          with_instance = self.instructions[with_variable_uuid]
          add_combine_history(to_combine_instance, with_instance)
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