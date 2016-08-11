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
      yum install -y $packages
      ;;
    "debian")
      echo "installing with apt..."
      apt-get install -y $packages
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
  ln -s `which gem` /opt/chef/embedded/bin/
  ln -s `which ruby` /opt/chef/embedded/bin/
}

machine=`uname -m`
os=`uname -s`

if test -f "/etc/lsb-release" && grep -q DISTRIB_ID /etc/lsb-release && ! grep -q wrlinux /etc/lsb-release; then
  platform=`grep DISTRIB_ID /etc/lsb-release | cut -d "=" -f 2 | tr '[A-Z]' '[a-z]'`
  platform_version=`grep DISTRIB_RELEASE /etc/lsb-release | cut -d "=" -f 2`
  
  if test "$platform" = "ubuntu"; then
    platform="debian"
  fi
  
elif test -f "/etc/debian_version"; then
  platform="debian"
  platform_version=`cat /etc/debian_version`
elif test -f "/etc/redhat-release"; then
  platform=`sed 's/^\(.\+\) release.*/\1/' /etc/redhat-release | tr '[A-Z]' '[a-z]'`
  platform_version=`sed 's/^.\+ release \([.0-9]\+\).*/\1/' /etc/redhat-release`

  # If /etc/redhat-release exists, we act like RHEL by default
  if test "$platform" = "fedora"; then
    # FIXME: remove client side platform_version mangling and hard coded yolo
    # Change platform version for use below.
    platform="redhat"
    platform_version="6.0"
  fi

  if test "$platform" = "xenserver"; then
    # Current XenServer 6.2 is based on CentOS 5, platform is not reset to "el" server should hanlde response
    platform="xenserver"
  else
    # FIXME: use "redhat"
    platform="redhat"
  fi

elif test -f "/etc/system-release"; then
  platform=`sed 's/^\(.\+\) release.\+/\1/' /etc/system-release | tr '[A-Z]' '[a-z]'`
  platform_version=`sed 's/^.\+ release \([.0-9]\+\).*/\1/' /etc/system-release | tr '[A-Z]' '[a-z]'`
  # amazon is built off of fedora, so act like RHEL
  if test "$platform" = "amazon linux ami"; then
    # FIXME: remove client side platform_version mangling and hard coded yolo
    platform="redhat"
    platform_version="6.0"
  fi
# Apple OS X
elif test -f "/usr/bin/sw_vers"; then
  platform="mac_os_x"
  # Matching the tab-space with sed is error-prone
  platform_version=`sw_vers | awk '/^ProductVersion:/ { print $2 }' | cut -d. -f1,2`

  # x86_64 Apple hardware often runs 32-bit kernels (see OHAI-63)
  x86_64=`sysctl -n hw.optional.x86_64`
  if test $x86_64 -eq 1; then
    machine="x86_64"
  fi
elif test -f "/etc/release"; then
  machine=`/usr/bin/uname -p`
  if grep -q SmartOS /etc/release; then
    platform="smartos"
    platform_version=`grep ^Image /etc/product | awk '{ print $3 }'`
  else
    platform="solaris2"
    platform_version=`/usr/bin/uname -r`
  fi
elif test -f "/etc/SuSE-release"; then
  if grep -q 'Enterprise' /etc/SuSE-release;
  then
      platform="sles"
      platform_version=`awk '/^VERSION/ {V = $3}; /^PATCHLEVEL/ {P = $3}; END {print V "." P}' /etc/SuSE-release`
  else
      platform="suse"
      platform_version=`awk '/^VERSION =/ { print $3 }' /etc/SuSE-release`
  fi
elif test "x$os" = "xFreeBSD"; then
  platform="freebsd"
  platform_version=`uname -r | sed 's/-.*//'`
elif test "x$os" = "xAIX"; then
  platform="aix"
  platform_version="`uname -v`.`uname -r`"
  machine="powerpc"
elif test -f "/etc/os-release"; then
  . /etc/os-release
  if test "x$CISCO_RELEASE_INFO" != "x"; then
    . $CISCO_RELEASE_INFO
  fi

  platform=$ID
  platform_version=$VERSION
fi

if test "x$platform" = "x"; then
  echo "Unable to determine platform version!"
  report_bug
  exit 1
fi

# do the thing
install_file $platform

