class Trace

  def self.Init(dir)
    begin
      @@out = File.new(File.join(dir, "listing"), "w");
    rescue
      raise "-- could not open trace file"
      @@out=$stdout
    end
  end

  def self.print(s)
    @@out.print(s)
  end
  
  def self.println(s="")
    @@out.puts(s)
  end
  
  def self.out
    @@out
  end

end
