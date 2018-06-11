#! /usr/bin/env bash

set -e

UML_VERSION=$(ruby -I ./lib -e "require 'vagrant-uml/version.rb' ; p VagrantPlugins::UML::VERSION" | tr  -d '"')
BOX_VERSION=0.0.2

echo "Install vagrant plugin"
vagrant plugin install ./pkg/vagrant-uml-${UML_VERSION}.gem

echo "Get Vagrant UML box (v${BOX_VERSION}"
vagrant box add https://alg-archistore.s3.amazonaws.com/public/infra/vagrant/uml/xenial64/box_metadata-${BOX_VERSION}.json

mkdir /tmp/instance
pushd /tmp/instance

echo "Init the UML instance"
vagrant init algolia/uml/xenial64

# Ensure the boot process will not report an error
cat <<EOF >Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.provider "uml"
  config.vm.box = "algolia/uml/xenial64"
  config.vm.boot_timeout=600
  config.vm.provider "uml" do |vb|
    vb.memory = 2048
    vb.cpus = 2
  end
end
EOF

echo "Display sudo rules"
vagrant uml-sudoers -c

echo "Start the UML instance"
vagrant up --provider=uml

echo "Try vagrant ssh -c"
vagrant ssh -c 'uname -a' | grep -q '^Linux'

echo "Stop the UML instance"
vagrant halt
popd

exit 0

