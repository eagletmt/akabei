require "bundler/gem_tasks"

task :default => :spec

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
namespace :spec do
  task :set_arch do
    ENV['AKABEI_ARCH_SPEC'] = '1'
  end

  desc 'Run RSpec examples including :arch. It requires sudo and devtools package.'
  task :arch => %w[spec:set_arch spec]
end

namespace :template do
  desc 'Update makepkg.conf and pacman.conf'
  task :update do
    h = `LANG=C pacman -Qi pacman`.each_line.map(&:chomp).each_with_object({}) do |line, h|
      next if line.empty?
      m = line.match(/\A([^:]+?)\s*:\s*(.+)\z/)
      h[m[1]] = m[2]
    end
    current_pacman = h['Version']

    require 'akabei/archive_utils'
    cache_dir = '/var/cache/pacman/pkg'
    template_dir = Pathname.new(__FILE__).join('../lib/akabei/omakase/templates')
    %w[i686 x86_64].each do |arch|
      Akabei::ArchiveUtils.each_entry("#{cache_dir}/pacman-#{current_pacman}-#{arch}.pkg.tar.xz") do |entry, archive|
        case entry.pathname
        when 'etc/makepkg.conf'
          puts "Update makepkg.#{arch}.conf"
          template_dir.join("makepkg.#{arch}.conf").open('w') { |f| f.write(archive.read_data) }
        when 'etc/pacman.conf'
          puts "Update pacman.#{arch}.conf"
          template_dir.join("pacman.#{arch}.conf").open('w') { |f| f.write(archive.read_data) }
        end
      end
    end
  end
end
