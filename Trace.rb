package Coco;

class Trace
	def Trace.Init(String dir)
	  begin
	    out = File.new(dir + "listing", "w");
	  rescue
	    Scanner.err.Exception("-- could not open trace file");
	    out=$stdout
	  end
	end

	def Trace.print(s)
	  out.print(s)
	end
	
	def Trace.println(s)
	  out.println(s)
	end
	
	def Trace.println()
	  out.println()
	end
end
