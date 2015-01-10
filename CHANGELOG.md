# 0.4.1 (2015-01-10)
- Do not depend on aws-sdk-resources

# 0.4.0 (2014-11-02)
- Switch to AWS SDK for Ruby v2

# 0.3.5 (2014-05-09)
- Update makepkg.conf template for pacman 4.1.2-6

# 0.3.4 (2014-03-09)
- Improve signal handling

# 0.3.3 (2014-03-07)
- Fix gpg-agent check

# 0.3.2 (2014-03-07) (yanked)
- Require gpg-agent

# 0.3.1 (2014-01-24)
- Fix typo in Akabei::Signer::KeyNotFound
- Create destination directories if missing

# 0.3.0 (2014-01-23)
- Add `akabei omakase remove` command
- Add `akabei version` command
- Check package_dir before executing any commands

# 0.2.1 (2014-01-19)
- Fix Repository#add to remove old entry with same pkgname

# 0.2.0 (2014-01-19)
- Add omakase mode
    - akabei omakase init
    - akabei omakase init --s3
    - akabei omakase build

# 0.1.0 (2014-01-17)
- Initial release
    - akabei build
    - akabei abs-add
    - akabei abs-remove
    - akabei files-add
    - akabei files-remove
    - akabei repo-add
    - akabei repo-remove
