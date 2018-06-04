#! /usr/bin/env bash

set -e

# Use the ruby version embedded with vagrant
export PATH=/opt/vagrant/embedded/bin:$PATH 

echo "Bundler install needed gems"
gem install bundler
bundle install --no-deployment

echo "Building plugin"
bundle exec rake

echo "Installing vagrant plugin"
vagrant plugin install ./pkg/vagrant-uml-0.0.2.gem

echo "Getting Vagrant UML box"
vagrant box add https://alg-archistore.s3.amazonaws.com/public/infra/vagrant/uml/xenial64/algolia_uml_xenial64-0.0.2.box

echo "Try the UML instance"
mkdir /tmp/instance
pushd /tmp/instance
vagrant init algolia/uml/xenial64

vagrant up --provider=uml
vagrant ssh -c "uname -a"
vagrant halt
popd

exit 0

