
class ParserGen

  MaxSymSets = 128;	# max. nr. of symbol sets
  MaxTerm    = 3;	# sets of size < maxTerm are enumerated
  CR         = '\r';
  LF         = '\n';
  TAB        = '\t';
  EOF        = '\uffff';

  TErr = 0;		# error codes
  AltErr = 1;
  SyncErr = 2;
	
  @@maxSS = 0;				# number of symbol sets
  @@errorNr = 0;			# highest parser error number
  @@curSy = 0;			# symbol whose production is currently generated
  @@fram = nil;		# parser frame file
  @@gen = nil;		# generated parser source file
  @@err = nil;		# generated parser error messages
  @@srcName = "";		# name of attribute grammar file
  @@srcDir = "";		# directory of attribute grammar file
  @@symSet = [];
	
  def self.Init(file, dir)
  end

  def self.GetString(beg, nd)
    s = ""
    oldPos = Buffer.pos
    Buffer.Set(beg)
    while (beg < nd) do
      s += Buffer.read.chr
      beg += 1
    end
    Buffer.Set(oldPos)
    return s.to_s
  end

end

__END__
