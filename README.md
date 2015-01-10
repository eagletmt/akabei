# Akabei
[![Gem Version](https://badge.fury.io/rb/akabei.svg)](https://badge.fury.io/rb/akabei)
[![Build Status](https://api.travis-ci.org/eagletmt/akabei.svg)](https://travis-ci.org/eagletmt/akabei)
[![Code Climate](https://codeclimate.com/github/eagletmt/akabei.svg)](https://codeclimate.com/github/eagletmt/akabei)
[![Coverage Status](https://img.shields.io/coveralls/eagletmt/akabei.svg)](https://coveralls.io/r/eagletmt/akabei)

Custom repository manager for ArchLinux pacman.

## Installation

Add this line to your application's Gemfile:

    gem 'akabei'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install akabei

## Usage
### Build a package and store it to a repository
Basic usage: build foo x86_64 package for bar repository.

```
% ls foo
PKGBUILD
% mkdir -p repo/x86_64
% akabei build foo --repo-dir repo/x86_64 --repo-name bar --arch x86_64
(snip)
% ls repo/x86_64
bar.abs.tar.gz  bar.db  bar.files  foo-1.0.0-1-x86_64.pkg.tar.xz
```

With full options:
```
% [ -z $GPG_AGENT_INFO ] && eval `gpg-agent --daemon`
% akabei build foo --chroot-dir /var/cache/akabei/chroot-x86_64 --repo-dir repo/x86_64 --repo-name bar --arch x86_64 --package-key $GPGKEY --repo-key $GPGKEY --pacman-config pacman.x86_64.conf --makepkg-config makepkg.x86_64.conf --srcdest sources --logdest logs
(snip)
% ls repo/x86_64
bar.abs.tar.gz  bar.db  bar.db.sig  bar.files  bar.files.sig  foo-1.0.0-1-x86_64.pkg.tar.xz  foo-1.0.0-1-x86_64.pkg.tar.xz.sig
% ls sources
foo-1.0.0.tar.gz
% ls logs
foo-1.0.0-1-x86_64-build.log  foo-1.0.0-1-x86_64-package.log
```

## Omakase mode
Omakase mode supports a typical situation managing the custom repository.

### Initialize a repository
`--repo-key` and `--package-key` are optional.

```
% akabei omakase init foo --repo-key $GPGKEY --package-key $GPGKEY
      create  .akabei.yml
      create  foo
      create  sources
      create  logs
      create  PKGBUILDs
      create  etc
      create  etc/makepkg.i686.conf
      create  etc/pacman.i686.conf
      create  etc/makepkg.x86_64.conf
      create  etc/pacman.x86_64.conf
Edit etc/makepkg.*.conf and set PACKAGER first!
% echo 'PACKAGER="John Doe <john@doe.com>"' >> etc/makepkg.i686.conf
% echo 'PACKAGER="John Doe <john@doe.com>"' >> etc/makepkg.x86_64.conf
```

### Build a package
Write a PKGBUILD in `PKGBUILDs/#{pkgname}` directory.

```
% mkdir PKGBUILDs/bar
% vim PKGBUILDs/bar/PKGBUILD
```

Then build the package.

```
% akabei omakase build bar
(snip)
% tree foo
foo
`-- os
    |-- i686
    |   |-- bar-1.0.0-1-i686.pkg.tar.xz
    |   |-- bar-1.0.0-1-i686.pkg.tar.xz.sig
    |   |-- foo.abs.tar.gz
    |   |-- foo.db
    |   |-- foo.db.sig
    |   `-- foo.files
    `-- x86_64
        |-- bar-1.0.0-1-x86_64.pkg.tar.xz
        |-- bar-1.0.0-1-x86_64.pkg.tar.xz.sig
        |-- foo.abs.tar.gz
        |-- foo.db
        |-- foo.db.sig
        `-- foo.files
```

### Publish the repository
For the server, serve files under the foo directory by HTTP server like nginx or Apache.

For clients, add the server's repository configuration to /etc/pacman.conf like below.

```
[foo]
SigLevel = Required
Server = http://example.com/$repo/os/$arch
```

### Publish the repository (Amazon S3)
Initialize repository with `--s3` option and set your credentials to .akabei.yml.
aws-sdk gem is required.

Each time you execute `akabei omakase build`:

1. Download repository databases (not including packages)
2. Build a package
3. Upload the built package and repository databases.

## Contributing

1. Fork it ( https://github.com/eagletmt/akabei/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
