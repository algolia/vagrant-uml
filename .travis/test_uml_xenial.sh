#! /usr/bin/env bash

set -e

rake build
vagrant plugin install ./pkg/vagrant-uml-0.0.2.gem
vagrant box add https://alg-archistore.s3.amazonaws.com/public/infra/vagrant/uml/xenial64/algolia_uml_xenial64-0.0.2.box

mkdir /tmp/instance
pushd /tmp/instance
vagrant init algolia/uml/xenial64
vagrant up --provider=uml
vagrant ssh -c "uname -a"
vagrant halt
popd

exit 0

