desc "rake install && rake build:checksum && bundle info f_dot"
task :make do
  exec "rake install && rake build:checksum && bundle info f_dot"
end
