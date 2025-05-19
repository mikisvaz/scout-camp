require 'scout'
require 'scout/path'
require 'scout/resource'
Path.add_path :scout_camp_lib, File.join(Path.caller_lib_dir(__FILE__), "{TOPLEVEL}/{SUBPATH}")
require 'scout/terraform_dsl'
require 'scout/offsite'
require 'scout/aws/s3'
