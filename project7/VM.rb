class Parser
  attr_accessor :input
  def initialize(file)
    @input = File.open("#{file.gsub('.vm', '')}tmp", "w+")
    file = File.open("#{file}", "r")
    file.readlines.each do |line|
      unless /\S/ !~ line.gsub(/\/\/.+/, '')
        @input << line.gsub(/\/\/.+/, '').strip + "\n"
      end
    end
    @input.rewind
  end

  def close
    @input.close
  end

  def command_type(line)
    case line.split(' ').first
      when 'push'     then return 'C_PUSH'
      when 'pop'      then return 'C_POP'
      when 'label'    then return 'C_LABEL'
      when 'goto'     then return 'C_GOTO'
      when 'if-goto'  then return 'C_IF'
      when 'call'     then return 'C_CALL'
      when 'function' then return 'C_FUNCTION'
      when 'return'   then return 'C_RETURN'
      else
        return 'C_ARITHMETIC'
    end
  end

  def segment(line)
    if command_type(line) == 'C_ARITHMETIC'
      return line.strip
    else
      arg = line.split(' ')
      seg = arg[1]
      case seg
        when 'local'    then return 'LCL'
        when 'argument' then return 'ARG'
        when 'this'     then return 'THIS'
        when 'that'     then return 'THAT'
        when 'temp'     then return 'TEMP'
        when 'pointer'  then return 'POINTER'
        when 'static'   then return 'STATIC'
        else
          return 'CONSTANT'
      end
    end
  end

  def index(line)
    arg = line.split(' ')
    return arg[2]
  end
end

class CodeWriter

  def initialize (output_name)
    @label_number = 0
    output_name = output_name.gsub('.vm', '') + '.asm'
    @output = File.open("#{output_name}", "w+")
  end

  def new_file(file)
    @file_name = file
  end

  def write_arithmetic(command)
    if command == 'add'
      @output << "@SP\nAM=M-1\nD=M\n" # Top of stack into D
      @output << "@SP\nAM=M-1\nD=D+M\n" # D contains added values
      @output << "@SP\nA=M\nM=D\n@SP\nM=M+1\n" # Write and increment stack
    elsif command == 'sub'
      @output << "@SP\nAM=M-1\nD=M\n"
      @output << "@SP\nAM=M-1\nD=M-D\n"
      @output << "@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    elsif command == 'neg'
      @output << "@SP\nAM=M-1\nD=-M\n"
      @output << "@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    elsif command == 'eq'
      @output << "@SP\nAM=M-1\nD=M\n"
      @output << "@SP\nAM=M-1\nD=D-M\n"
      @output << "@EQ_LABEL#{@label_number}\nD;JEQ\n"
      @output << "@SP\nA=M\nM=0\n@SP\nM=M+1\n@CONTINUE_LABEL#{@label_number}\n0;JMP\n"
      @output << "(EQ_LABEL#{@label_number})\n@SP\nA=M\nM=-1\n@SP\nM=M+1\n"
      @output << "(CONTINUE_LABEL#{@label_number})\n"
      @label_number += 1
    elsif command == 'gt'
      @output << "@SP\nAM=M-1\nD=M\n"
      @output << "@SP\nAM=M-1\nD=M-D\n"
      @output << "@GT_LABEL#{@label_number}\nD;JGT\n"
      @output << "@SP\nA=M\nM=0\n@SP\nM=M+1\n@CONTINUE_LABEL#{@label_number}\n0;JMP\n"
      @output << "(GT_LABEL#{@label_number})\n@SP\nA=M\nM=-1\n@SP\nM=M+1\n"
      @output << "(CONTINUE_LABEL#{@label_number})\n"
      @label_number += 1
    elsif command == 'lt'
      @output << "@SP\nAM=M-1\nD=M\n"
      @output << "@SP\nAM=M-1\nD=M-D\n"
      @output << "@LT_LABEL#{@label_number}\nD;JLT\n"
      @output << "@SP\nA=M\nM=0\n@SP\nM=M+1\n@CONTINUE_LABEL#{@label_number}\n0;JMP\n"
      @output << "(LT_LABEL#{@label_number})\n@SP\nA=M\nM=-1\n@SP\nM=M+1\n"
      @output << "(CONTINUE_LABEL#{@label_number})\n"
      @label_number += 1
    elsif command == 'and'
      @output << "@SP\nAM=M-1\nD=M\n"
      @output << "@SP\nAM=M-1\nD=D&M\n"
      @output << "@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    elsif command == 'or'
      @output << "@SP\nAM=M-1\nD=M\n"
      @output << "@SP\nAM=M-1\nD=D|M\n"
      @output << "@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    elsif command == 'not'
      @output << "@SP\nAM=M-1\nD=!M\n"
      @output << "@SP\nA=M\nM=D\n@SP\nM=M+1\n"
    else
      puts "Unknown command: #{command}"
    end
  end

  def write_push_pop(command, segment, index)
    if command == 'C_PUSH'
      if segment == 'CONSTANT'
        @output << "@#{index}\nD=A\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
      elsif segment == 'TEMP'
        @output << "@#{index.to_i+5}\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
      elsif segment == 'POINTER'
        @output << "@#{index.to_i+3}\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
      elsif segment == 'STATIC'
        @output << "@#{@file_name}.#{index}\nD=M\n@SP\nA=M\nM=D\n@SP\nM=M+1\n"
      else
        @output << "@#{index}\nD=A\n@#{segment}\nA=M\nA=D+A\nD=M\n"
        @output << "@SP\nA=M\nM=D\n@SP\nM=M+1\n"
       end
    else #command == 'C_POP'
      if segment == 'TEMP'
        @output << "@SP\nAM=M-1\nD=M\n@#{index.to_i+5}\nM=D\n"
      elsif segment == 'POINTER'
        @output << "@SP\nAM=M-1\nD=M\n@#{index.to_i+3}\nM=D\n"
      elsif segment == 'STATIC'
        @output << "@SP\nAM=M-1\nD=M\n@#{@file_name}.#{index}\nM=D\n"
      else
      @output << "@#{index}\nD=A\n@#{segment}\nA=D+M\nD=A\n@R13\nM=D\n"
      @output << "@SP\nAM=M-1\nD=M\n@R13\nA=M\nM=D\n"
    end
    end
  end

  def close
    @output << "(END)\n@END\n0;JMP\n"
    @output.close
  end
end

input = ARGV.first
coder = CodeWriter.new(input)
parsers = []

if input.include?('.vm')
  parsers << Parser.new(input)
else
  Dir.chdir(input)
  Dir.glob("*.vm") do |file|
    parsers << Parser.new(file) if file.include?(".vm")
  end
end
parsers.each do |parser|
  coder.new_file(parser)
  parser.input.readlines.each do |line|
    command = parser.command_type(line.strip)
    if command == 'C_ARITHMETIC'
      coder.write_arithmetic(line.strip)
    elsif command == 'C_PUSH' or command == 'C_POP'
      segment = parser.segment(line.strip)
      index   = parser.index(line.strip)
      coder.write_push_pop(command, segment, index)
    end
  end
end
parsers.each { |parser| parser.close }
coder.close
