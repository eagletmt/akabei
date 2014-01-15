# Akabei
[![Code Climate](https://codeclimate.com/github/eagletmt/akabei.png)](https://codeclimate.com/github/eagletmt/akabei)

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
% akabei build foo --chroot-dir /tmp/chroot-x86_64 --repository-dir repo/x86_64 --repository-name bar --arch x86_64
(snip)
% ls repo/x86_64
bar.abs.tar.gz  bar.db  bar.files  foo-1.0.0-1-x86_64.pkg.tar.xz
```

With full options:
```
% [ -z $GPG_AGENT_INFO ] && eval `gpg-agent --daemon`
% akabei build foo --chroot-dir /tmp/chroot-x86_64 --repository-dir repo/x86_64 --repository-name bar --arch x86_64 --package-key $GPGKEY --repository-key $GPGKEY --pacman-config pacman.x86_64.conf --makepkg-config makepkg.x86_64.conf --srcdest sources --logdest logs
(snip)
% ls repo/x86_64
bar.abs.tar.gz  bar.db  bar.db.sig  bar.files  bar.files.sig  foo-1.0.0-1-x86_64.pkg.tar.xz  foo-1.0.0-1-x86_64.pkg.tar.xz.sig
% ls sources
foo-1.0.0.tar.gz
% ls logs
foo-1.0.0-1-x86_64-build.log  foo-1.0.0-1-x86_64-package.log
```

## Contributing

1. Fork it ( https://github.com/eagletmt/akabei/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
