require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

task :default => :test

desc "Run the tests"
Rake::TestTask::new do |t|
    t.test_files = FileList['test/test*.rb']
    t.verbose = true
end

desc "Generate the documentation"
Rake::RDocTask::new do |rdoc|
  rdoc.rdoc_dir = 'georuby-doc/'
  rdoc.title    = "GeoRuby Documentation"
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

spec = Gem::Specification::new do |s|
  s.platform = Gem::Platform::RUBY

  s.name = 'GeoRuby'
  s.version = "1.3.4"
  s.summary = "Ruby data holder for OGC Simple Features"
  s.description = <<EOF
GeoRuby is intended as a holder for data returned from PostGIS and MySQL Spatial queries. The data model roughly follows the OGC "Simple Features for SQL" specification (see www.opengis.org/docs/99-049.pdf), although without any kind of advanced functionalities (such as geometric operators or reprojections)
EOF
  s.author = 'Guilhem Vellut'
  s.email = 'guilhem.vellut@gmail.com'
  s.homepage = "http://thepochisuperstarmegashow.com/projects/"
  
  s.requirements << 'none'
  s.require_path = 'lib'
  s.files = FileList["lib/**/*.rb", "test/**/*.rb", "README","MIT-LICENSE","rakefile.rb","test/data/*.shp","test/data/*.dbf","test/data/*.shx","tools/**/*.yml","tools/**/*.rb","tools/lib/**/*"]
  s.test_files = FileList['test/test*.rb']

  s.has_rdoc = true
  s.extra_rdoc_files = ["README"]
  s.rdoc_options.concat ['--main',  'README']
end

desc "Package the library as a gem"
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end
