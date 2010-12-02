require 'ubygems'
require 'terminal-table/import'

CGROUPFS = "/cgroup"

$cgroups = {}
def read_values!(path = '/')
  fpath = CGROUPFS + path

  tasks = []
  IO.readlines(fpath + '/tasks').each do |l|
    l.chomp!
    tasks << l
  end
  mem_usage = IO.readlines(fpath + '/memory.usage_in_bytes').to_s.to_i
  memsw_usage = IO.readlines(fpath + '/memory.memsw.usage_in_bytes').to_s.to_i
  cpu_elapsed = IO.readlines(fpath + '/cpuacct.usage').to_s.to_f / 1E9
  cpu_usage = cpu_elapsed - ($cgroups[path] && $cgroups[path][:cpu] || cpu_elapsed)

  $cgroups[path] = { :tasks => tasks.length,
    :mem => mem_usage,
    :swap => memsw_usage - mem_usage,
    :cpu => cpu_elapsed,
    :usage => cpu_usage
  }

  # Recurse
  Dir.foreach(fpath) do |f|
    if f =~ /^[^\.]/ && File.directory?(fpath + f)
      read_values!(path + (path =~ /\/$/ ? '' : '/') + f)
    end
  end
end

def human(i)
  affix = ''
  units = %w(K M G T P E)
  while i >= 8192 && units.length > 0
    i /= 1024
    affix = units.shift
  end
  "#{i}#{affix}"
end

def display!
  keys = $cgroups.keys.sort
  puts table([nil, 'Tasks', 'Mem', 'Swap', 'CPU [s]', 'CPU%'],
             *keys.select { |g|
	       $cgroups[g][:tasks] > 0
             }.map { |g|
               [g, $cgroups[g][:tasks],
                human($cgroups[g][:mem]), human($cgroups[g][:swap]),
                ($cgroups[g][:cpu] * 1000).to_i / 1000.0, ($cgroups[g][:usage] * 100).to_i]
             })
end

loop do
  last_tick = Time.now.to_f
  read_values!
  #p $cgroups

  display!

  delay = last_tick + 1 - Time.now.to_f
  sleep delay if delay > 0
end
