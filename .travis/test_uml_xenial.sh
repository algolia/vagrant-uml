#! /usr/bin/env bash

set -e

UML_VERSION=$(ruby -I ./lib -e "require 'vagrant-uml/version.rb' ; p VagrantPlugins::UML::VERSION" | tr  -d '"')
BOX_VERSION=0.0.2

echo "Installing vagrant plugin"
vagrant plugin install ./pkg/vagrant-uml-${UML_VERSION}.gem

echo "Getting Vagrant UML box"
vagrant box add https://alg-archistore.s3.amazonaws.com/public/infra/vagrant/uml/xenial64/box_metadata-${BOX_VERSION}.json

echo "Try the UML instance"
mkdir /tmp/instance
pushd /tmp/instance
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

vagrant up --provider=uml
vagrant halt
popd

exit 0

