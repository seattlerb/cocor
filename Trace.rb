class Trace
  def Trace.Init(dir)
    begin
      out = File.new(File.join(dir, "listing"), "w");
    rescue
      Scanner.err.Exception("-- could not open trace file");
      out=$stdout
    end
  end

  def Trace.print(s)
    out.print(s)
  end
  
  def Trace.println(s)
    out.puts(s)
  end
  
  def Trace.println()
    out.puts()
  end
end
