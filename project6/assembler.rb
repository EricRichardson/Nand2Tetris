module Parser

    def initializer (file)
      input = File.open("tmp.asm", "w+")
      File.readlines(file).each do |line|
        unless /\S/ !~ line.gsub(/\/\/.+/, '')
          input << line.gsub(/\/\/.+/, '').strip + "\n"
        end
      end
      input
    end

    def command_type(current_command)
      type = String.new
      if current_command =~ /@.+/
        type = "A_CMD"
      elsif current_command.include?('=') or current_command.include?(';')
        type = "C_CMD"
      else
        type = "L_CMD"
      end
      type
    end

    def dest (line)
      line[/\w+(?=\=)/] # characters before =
    end

    def comp (line)
     line.gsub(/\w+\=/, '').gsub(/;\w+/, '') # strip characters before and after ;
    end

    def jump (line)
      line[/(?<=;)\w+/] # 3 word characters after a ;
    end
end

module Code
  def code_comp (component)
    a = String.new
    if component.include?('M')
      a << '1'
      component.gsub!('M', 'A')
    else
      a << '0'
    end
    case component.strip
    when '0'   then return a + '101010'
    when '1'   then return a + '111111'
    when '-1'  then return a + '111010'
    when 'D'   then return a + '001100'
    when 'A'   then return a + '110000'
    when '!D'  then return a + '001101'
    when '!A'  then return a + '110001'
    when '-D'  then return a + '001111'
    when '-A'  then return a + '110011'
    when 'D+1' then return a + '011111'
    when 'A+1' then return a + '110111'
    when 'D-1' then return a + '001110'
    when 'A-1' then return a + '110010'
    when 'D+A' then return a + '000010'
    when 'D-A' then return a + '010011'
    when 'A-D' then return a + '000111'
    when 'D&A' then return a + '000000'
    when 'D|A' then return a + '010101'
    else
      puts "ERROR! The comp calc component was: #{component}"
    end
  end

  def code_dest (component)
    destination = Array.new(3, '0')
    destination[0] = '1' if component.include?('A')
    destination[1] = '1' if component.include?('D')
    destination[2] = '1' if component.include?('M')
    destination.join
  end

  def code_jump (component)
    case component
    when 'JGT' then return '001'
    when 'JEQ' then return '010'
    when 'JGE' then return '011'
    when 'JLT' then return '100'
    when 'JNE' then return '101'
    when 'JLE' then return '110'
    when 'JMP' then return '111'
    when ''    then return '000'
    else
      raise
    end
  end

  def dec_to_bin (number)
    number.to_i.to_s(2)
  end
end

class SymbolTable
  attr_accessor :symbols
  @symbols = Hash.new
  def initialize
    @symbols = { '@SP' => '@0', '@LCL' => '@1', '@ARG' => '@2', '@THIS' => '@3', '@THAT' => '@4',
    '@R0' => '@0', '@R1' => '@1', '@R2' => '@2', '@R3' => '@3', '@R4' => '@4', '@R5' => '@5', '@R6' => '@6',
    '@R7' => '@7', '@R8' => '@8', '@R9' => '@9', '@R10' => '@10', '@R11' => '@11', '@R12' => '@12',
    '@R13' => '@13', '@R14' => '@14', '@R15' => '@15', '@SCREEN' => '@16384', '@KBD' =>  '@24576' }
  end

  def add_symbol(symbol, address)
    @symbols[symbol] = "@#{address.to_s}"
  end

  def contains?(symbol)
    @symbols.has_key?(symbol)
  end

  def get_address(symbol)
    @symbols[symbol]
  end
end

class Assembler
  include Parser
  include Code
end

rom_address = 0
ram_address = 16
symbols = SymbolTable.new
assembler = Assembler.new
puts "What file do you want assembled?"
input_name = gets.chomp
output_name = input_name.gsub(".asm", ".hack")
input = assembler.initializer(input_name)
output = File.open("#{output_name}", "w")
input.rewind

File.readlines(input).each do |line| # First pass
  if assembler.command_type(line) == "L_CMD"
    label = "@#{line.gsub("\(", '').gsub("\)", '').strip}"
   symbols.add_symbol(label, rom_address) unless symbols.contains?(label)
  else
    rom_address += 1
  end
end

input.rewind
temp = File.open("tmp_wo_labels.asm", "w+")
File.readlines(input).each do |line| # Second pass
  if assembler.command_type(line) == 'A_CMD' or assembler.command_type(line) == 'C_CMD'
    if line =~ /@\d+/ or assembler.command_type(line) == 'C_CMD'
      temp << line
    elsif symbols.contains?(line.chomp)
      temp << symbols.get_address(line.chomp) + "\n"
    else
      symbols.add_symbol(line.chomp, ram_address)
      temp << symbols.get_address(line.chomp) + "\n"
      ram_address += 1
    end
  end
end

temp.rewind

File.readlines(temp).each do |line| # Main pass
  if assembler.command_type(line) == "A_CMD"
    i = 0
    zeros = String.new
    length = assembler.dec_to_bin(line.gsub('@', '')).length
    while(i + length < 16) do
      zeros << "0"
      i += 1
    end
    output << zeros + assembler.dec_to_bin(line.gsub('@', '')) + "\n"
  else # C_CMD
    c = assembler.comp(line)
    d = assembler.dest(line)
    d ||= ''
    j = assembler.jump(line)
    j ||= ''
    cc = assembler.code_comp(c)
    dd = assembler.code_dest(d)
    jj = assembler.code_jump(j)
    output << "111" + cc + dd + jj +"\n"
  end
end
temp.close
output.close
input.close
