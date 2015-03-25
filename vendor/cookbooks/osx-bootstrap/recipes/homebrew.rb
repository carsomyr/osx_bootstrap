# -*- coding: utf-8 -*-
#
# Copyright 2014 Roy Liu
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require "pathname"

homebrew_paths = [
    "/usr/local/bin", "/usr/local/sbin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"
]

homebrew_install_dirs = [
    ".", "bin", "etc", "include", "lib", "lib/pkgconfig", "sbin", "share", "var",
    "var/log", "share/locale", "share/man",
    "share/man/man1", "share/man/man2", "share/man/man3", "share/man/man4",
    "share/man/man5", "share/man/man6", "share/man/man7", "share/man/man8",
    "share/info", "share/doc", "share/aclocal",
    "Library", "Library/Taps"
].map { |dir_name| Pathname.new("/usr/local") + dir_name }

# Rearrange the `PATH` environment variable so that Homebrew's directories are searched first.
ruby_block "rearrange `ENV[\"PATH\"]`" do
  block do
    env_paths = ENV["PATH"].split(":", -1).uniq
    homebrew_env_paths = homebrew_paths & env_paths
    homebrew_remaining_paths = homebrew_paths - env_paths

    path_set = Set.new(homebrew_env_paths)
    index = 0

    ENV["PATH"] = (homebrew_remaining_paths + env_paths.map do |env_path|
      if path_set.include?(env_path)
        homebrew_path = homebrew_env_paths[index]
        index += 1
        homebrew_path
      else
        env_path
      end
    end).join(":")
  end

  action :run
end

file "/etc/paths" do
  content homebrew_paths.join("\n") + "\n"
  owner "root"
  group "wheel"
  mode 0644
  action :create
end

# Create `admin` group-writable directories in advance to work around Chef's interaction with Homebrew's installation
# script. When Chef shells out (see
# `https://github.com/opscode-cookbooks/homebrew/blob/v1.7.2/recipes/default.rb#L34-37`), it does so with the original
# process' group id, which may very well be 0. This then short circuits Homebrew's permission fixing logic
# (see `https://github.com/Homebrew/homebrew/blob/8eefd4e/install#L135`) when running under `sudo`.
homebrew_install_dirs.each do |dir|
  directory dir.to_s do
    owner "root"
    group "admin"
    mode 0775
    action :create
  end
end

# Install Homebrew.
include_recipe "homebrew"

# Enable `brew cask` functionality.
include_recipe "homebrew::cask"

# Create or update the Cask working directory with the proper permissions.
directory node["osx-bootstrap"]["homebrew"]["caskroom_path"] do
  owner "root"
  group "admin"
  mode 0775
  recursive true
  action :create
end