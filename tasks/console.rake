desc "run irb console with f_dot and autocomplete"
task :console do
  require :irb.to_s
  require :"irb/completion".to_s
  require :f_dot.to_s
  ARGV.clear
  IRB.start
end
