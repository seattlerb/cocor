# This file is generated. DO NOT MODIFY!

# TODO namespace/module starts here: package Coco;
require 'BitSet'
require 'module-hack'

class Token
  attr_accessor :kind, :pos, :col, :line, :val

  def initialize
    @val = ""
    @kind = @pos = @col = @line = 0
  end

  def clone
    return Marshal.load(Marshal.dump(self))
  end

  def ==(o)
    ! o.nil? &&
      @kind == o.kind &&
      @pos == o.pos &&
      @col == o.col &&
      @line == o.line &&
      @val == o.val
  end

  def to_s
    "<Token@#{self.id}: \"#{@val}\" k=#{@kind}, p=#{@pos}, c=#{@col}, l=#{@line}>"
  end

end

class Buffer

  # TODO: switch these to instance variables and clean this shit up
  @@buf = ""
  @@bufLen = 0
  @@pos = 0

  # cls_attr_accessor :pos
  def self.pos
    @@pos
  end
  
  def self.Fill(name)
    @@buf = File.new(name).read
    @@bufLen = @@buf.size
  end
  
  def self.Set(position)
    if (position < 0) then
      position = 0
    elsif (position >= @@bufLen) then
      position = @@bufLen
    end
    @@pos = position
  end
  
  def self.read
    c = 0
    if (@@pos < @@bufLen) then
      c = @@buf[@@pos]
      @@pos += 1
    else
      c = Scanner::MAXCHR
    end
    return c
  end
end

class Scanner

  @@err = nil					# error messages

  EOF = 0					# TODO: verify... 
  CR = "\r"[0]
  NL = "\n"[0]					# FIX: this sucks
  EOL = NL
  MAXASCII = 127				# FIX: this is dumb
  MAXCHR = 65535				# FIX: not ruby compatible
  SPACE = ' '[0]

	private; @@noSym = 39; # FIX: make this a constant
	private; @@start = [
 25,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
  0,  0,  6,  0,  5,  0,  0,  7, 12, 13,  0, 10, 16, 11,  9,  0,
  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  0,  0, 14,  8, 17,  0,
  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,
  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1, 19,  0, 20, 15,  0,
  0,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,
  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1, 21, 18, 22,  0,  0,
  0]


  # TODO: make fucking sure these become instance vars
  private
  @@t=Token.new			# current token
  @@ch=nil			# current input character
  @@pos=0			# position of current character
  @@line=0			# line number of current character
  @@lineStart=0			# start position of current line
  @@oldEols=0			# >0: no. of EOL in a comment
  @@ignore=BitSet.new(128)	# set of characters to be ignored by the scanner

  public 

  def self.err			# HACK: added because @@err was accessed from Parser.rb
    @@err
  end

  def self.Init(file, e=ErrorStream.new)
    @@ignore = BitSet.new(128)
		@@ignore.set(9)
@@ignore.set(10)
@@ignore.set(13)
@@ignore.set(32)

    @@err = e
    Buffer.Fill(file)
    @@pos = -1
    @@line = 1
    @@lineStart = 0
    @@oldEols = 0
    self.NextCh
  end
	
  def self.NextCh
    if (@@oldEols > 0) then
      @@ch = EOL
      @@oldEols -= 1
    else
      @@ch = Buffer.read
      @@pos += 1
      if (@@ch==NL || @@ch==CR) then
	@@line += 1
	@@lineStart = @@pos + 1
      end
    end
    if (@@ch > MAXASCII) then
      if (@@ch == MAXCHR) then
	@@ch = EOF
      else
	$stderr.puts("-- invalid character (#{@@ch}) at line #{@@line} col #{@@pos - @@lineStart}")
	@@ch = SPACE
      end
    end
  end
	
private; def self.Comment0()
	level = 1; line0 = @@line; lineStart0 = @@lineStart; startCh=nil
	NextCh()
	if (@@ch==?*) then
		NextCh()
		loop do
			if (@@ch==?*) then
				NextCh()
				if (@@ch==?/) then
					level -= 1
					if (level==0) then ; oldEols=@@line-line0; NextCh(); return true; end
					NextCh()
				end
			elsif (@@ch==?/) then
				NextCh()
				if (@@ch==?*) then
					level += 1; NextCh()
				end
			elsif (@@ch==EOF) then; return false
			else NextCh()
			end
		end
	else
		if (@@ch==EOL) then; @@line -= 1; @@lineStart = lineStart0; end
		@@pos -= 2; Buffer.Set(@@pos+1); NextCh()
	end
	return false
end

	
  def self.CheckLiteral
    case (@@t.val[0])
			when ?A
				if (@@t.val == "ANY") then; @@t.kind = 24
				end
			when ?C
				if (@@t.val == "CHARACTERS") then; @@t.kind = 11
				elsif (@@t.val == "CHR") then; @@t.kind = 21
				elsif (@@t.val == "COMMENTS") then; @@t.kind = 14
				elsif (@@t.val == "COMPILER") then; @@t.kind = 6
				elsif (@@t.val == "CONTEXT") then; @@t.kind = 36
				end
			when ?E
				if (@@t.val == "END") then; @@t.kind = 10
				end
			when ?F
				if (@@t.val == "FROM") then; @@t.kind = 15
				end
			when ?I
				if (@@t.val == "IGNORE") then; @@t.kind = 18
				end
			when ?N
				if (@@t.val == "NESTED") then; @@t.kind = 17
				end
			when ?P
				if (@@t.val == "PRAGMAS") then; @@t.kind = 13
				elsif (@@t.val == "PRODUCTIONS") then; @@t.kind = 7
				end
			when ?S
				if (@@t.val == "SYNC") then; @@t.kind = 35
				end
			when ?T
				if (@@t.val == "TO") then; @@t.kind = 16
				elsif (@@t.val == "TOKENS") then; @@t.kind = 12
				end
			when ?W
				if (@@t.val == "WEAK") then; @@t.kind = 30
				end

    end
  end

  def self.Scan
    buf=""
    self.NextCh while @@ignore[@@ch] # .get(@@ch)
		if (@@ch==?/ && Comment0() ) then ; return Scan(); end
    @@t = Token.new
    @@t.pos = @@pos
    @@t.col = @@pos - @@lineStart
    @@t.line = @@line 
    @@t.kind = "FIX"
    buf = ""
    state = @@start[@@ch]
    apx = 0

    while true
      buf += @@ch.chr unless @@ch < 0
      self.NextCh
#      $stderr.puts "state = #{state}, ch = #{@@ch} / '#{@@ch.chr}'"
      case state
      when 0				# NextCh already done
	@@t.kind = @@noSym
	break
				when 1
					if ((@@ch>=?0 && @@ch<=?9 || @@ch>=?A && @@ch<=?Z || @@ch>=?a && @@ch<=?z)) then
					else
@@t.kind = 2
@@t.val = buf.to_s; CheckLiteral()
break
end
				when 2
					@@t.kind = 3
break
				when 3
					if ((@@ch>=?0 && @@ch<=?9)) then
					else
@@t.kind = 4
break
end
				when 4
					@@t.kind = 5
break
				when 5
					if ((@@ch>=?0 && @@ch<=?9)) then
					else
@@t.kind = 40
break
end
				when 6
					if ((@@ch<=9 || @@ch>=11 && @@ch<=12 || @@ch>=14 && @@ch<=?! || @@ch>=?#)) then
					elsif ((@@ch==10 || @@ch==13)) then
state = 4
					elsif (@@ch==?") then
state = 2
					else
@@t.kind = @@noSym; break; end
				when 7
					if ((@@ch<=9 || @@ch>=11 && @@ch<=12 || @@ch>=14 && @@ch<=?& || @@ch>=?()) then
					elsif ((@@ch==10 || @@ch==13)) then
state = 4
					elsif (@@ch==39) then
state = 2
					else
@@t.kind = @@noSym; break; end
				when 8
					@@t.kind = 8
break
				when 9
					if (@@ch==?)) then
state = 24
					else
@@t.kind = 9
break
end
				when 10
					@@t.kind = 19
break
				when 11
					@@t.kind = 20
break
				when 12
					if (@@ch==?.) then
state = 23
					else
@@t.kind = 22
break
end
				when 13
					@@t.kind = 23
break
				when 14
					@@t.kind = 25
break
				when 15
					@@t.kind = 26
break
				when 16
					@@t.kind = 27
break
				when 17
					@@t.kind = 28
break
				when 18
					@@t.kind = 29
break
				when 19
					@@t.kind = 31
break
				when 20
					@@t.kind = 32
break
				when 21
					@@t.kind = 33
break
				when 22
					@@t.kind = 34
break
				when 23
					@@t.kind = 37
break
				when 24
					@@t.kind = 38
break
				when 25
					@@t.kind = 0

	break
      end
    end
#    puts "buf = '#{buf}' state = #{state} line=#{@@t.line} col=#{@@t.col} "
    @@t.val = buf.to_s

    raise "kind not set for Token" unless @@t.kind and @@t.kind != "FIX"

#    puts @@t

    return @@t
  end
end

