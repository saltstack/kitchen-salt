#!/bin/sh
##
## modified chef install script
## for kitchen-salt, the entirety of chef is not required
## but ruby and gem are required in a specific directory
## for kitchen tests to run
##

packages="ruby ruby-dev"

# install_file TYPE FILENAME
# TYPE is "rpm", "deb", "solaris", "sh", etc.
install_file() {
  echo "Installing the ruby things"
  case "$1" in
    "redhat")
      echo "installing with yum..."
      packages="ruby ruby-devel"
      yum install -y $packages
      ;;
    "debian")
      echo "installing with apt..."
      apt-get install -y $packages
      ;;
    "alpine")
      echo "installing with apk..."
      apk add $packages
      ;;
    "arch")
      echo "installing with pacman..."
      packages="ruby"
      pacman -Sy --noconfirm $packages
      # required as otherwise gems will be installed in user's directories
      echo "gem: --no-user-install" > /etc/gemrc
      ;;
    "osx")
      echo "installing with brew..."
      brew install $packages
      ;;
    "rvm")
      echo "installing with rvm..."
      gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
      \curl -sSL https://get.rvm.io | bash -s stable --ruby
      ;;
    *)
      echo "Unknown platform: $platform"
      exit 1
      ;;
  esac
  if test $? -ne 0; then
    echo "Installation failed"
    report_bug
    exit 1
  fi

  # make links to binaries
  mkdir -p /opt/chef/embedded/bin/
  [ ! -e /opt/chef/embedded/bin/gem ] && ln -s `which gem` /opt/chef/embedded/bin/
  [ ! -e /opt/chef/embedded/bin/ruby ] && ln -s `which ruby` /opt/chef/embedded/bin/
}

if test -f "/etc/debian_version" || test -f "/etc/devuan_version"; then
  platform="debian"
elif test -f "/etc/redhat-release"; then
  platform=`sed 's/^\(.\+\) release.*/\1/' /etc/redhat-release | tr '[A-Z]' '[a-z]'`

  if test "$platform" = "fedora"; then
    platform="redhat"
  fi

  if test "$platform" = "xenserver"; then
    platform="xenserver"
  else
    platform="redhat"
  fi
elif test -f "/etc/arch-release"; then
    platform="arch"
elif test -f "/etc/system-release"; then
  platform=`sed 's/^\(.\+\) release.\+/\1/' /etc/system-release | tr '[A-Z]' '[a-z]'`
  if test "$platform" = "amazon linux ami"; then
    platform="redhat"
  fi
elif test -f "etc/alpine-release"; then
  platform="alpine"
# Apple OS X
elif test -f "/usr/bin/sw_vers"; then
  platform="mac_os_x"
elif test -f "/etc/release"; then
  if grep -q SmartOS /etc/release; then
    platform="smartos"
  else
    platform="solaris2"
  fi
elif test -f "/etc/SuSE-release"; then
  if grep -q 'Enterprise' /etc/SuSE-release;
  then
    platform="sles"
  else
    platform="suse"
  fi
elif test "x$os" = "xFreeBSD"; then
  platform="freebsd"
elif test "x$os" = "xAIX"; then
  platform="aix"
elif test -f "/etc/os-release"; then
  . /etc/os-release
  if test "x$CISCO_RELEASE_INFO" != "x"; then
    . $CISCO_RELEASE_INFO
  fi

  platform=$ID
elif test -f "/etc/lsb-release" && grep -q DISTRIB_ID /etc/lsb-release && ! grep -q wrlinux /etc/lsb-release; then
  platform=`grep DISTRIB_ID /etc/lsb-release | cut -d "=" -f 2 | tr '[A-Z]' '[a-z]'`
fi

if test "x$platform" = "x"; then
  echo "Unable to determine platform version!"
  report_bug
  exit 1
fi

# do the thing
install_file $platform
exit 0
