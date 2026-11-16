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

      def compiler_contents
        {
          variables: self.variables.select{|k, v|
            k != FDot.state[:based_uuid] &&
            !FDot.state[:f_dot_queue].include?(k) &&
            !FDot.state[:programmer][:variables].include?(k) &&
            !FDot.state[:user][:variables].include?(k)
          }.map{|k, v| k},
          instructions: self.instructions.select{|k, v|
            !FDot.state[:programmer][:instructions].include?(k) &&
            !FDot.state[:user][:instructions].include?(k)
          }.map{|k, v| k},
        }
      end

      def compile!
        # get current compiler contents
        compiler_data = compiler_contents
        puts compiler_data
        return unless (compiler_data[:variables] || []).any? ||
          (compiler_data[:instructions] || []).any?
        compiler_variables = compiler_data[:variables].map{|v|
          FDot.state[:program].variables[v]
        }
        compiler_variables.each{|v1|
          combinable = compiler_variables.select{|v2|
            v1.uuid != v2.uuid &&
            v1.ordinal == v2.ordinal
          }
          if combinable.any?
            new_instruction = FDot::Based::Instruction.new(self.uuid, combinable.map{|v| v.uuid})
            FDot.state[:instructions] << new_instruction
          end
        }
        compiler_instructions = compiler_data[:instructions].map{|v|
          FDot.state[:program].instructions[v]
        }
        compiler_instructions.each{|i1|
          combinable = i1.select{|i2|
            i1.uuid != i2.uuid &&
            i1.ordinal == i2.ordinal
          }
          if combinable.any?
            FDot::Based::Instruction.create_with_combinable_instructions(
              self.uuid,
              combinable.map{|v| v.uuid}
            )
          end
        }

      end

      def add_move_history(variable, move_to_domain_key)
        move_to_domain_key = move_to_domain_key.to_sym

        # remove variable uuid from current domain
        if variable.domain_key == :processor
          FDot.state[:f_dot_queue].delete(variable.uuid)
        else
          FDot.state[variable.domain_key][:variables].delete(variable.uuid)
        end

        # create a history entry
        history[variable.uuid] ||= []
        history[variable.uuid] << FDot::Based::History.new(
          variable,
          FDot::DOMAINS[move_to_domain_key]
        )

        puts history[variable.uuid].last.to_s

        # add the variable to domain
        if move_to_domain_key != :processor
          FDot.state[move_to_domain_key][:variables] << variable.uuid
        end

        self.compile!
      end

      # deal out one variable
      def move_next_variable_to(move_to_domain_key)
        # get the next var
        next_var = FDot.state[:program].variables[
          FDot.state[:f_dot_queue].delete_at(0)
        ]

        self.add_move_history(next_var, move_to_domain_key)
      end

      def build_space!
        working_directory = FDot::Based.f_dot_space_path
        return unless FDot.state[:f_dot_queue].nil?

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

        # assign first round variables
        # to programmer and user domains
        FDot::Based::NUMBERS.each{|n|
          [:programmer, :user].each{|k|
            move_next_variable_to(k)
          }
        }
      end

    end
  end
end