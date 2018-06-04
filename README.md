# Vagrant UML Provider

This is a [Vagrant](http://www.vagrantup.com) plugin that adds an [User Mode Linux](http://user-mode-linux.sourceforge.net/)  provider to Vagrant, allowing it to start,shutdown/halt and ssh to UML local instances.

## Requirements

* [Vagrant](http://www.vagrantup.com/downloads.html) (tested with version 2.0*, 2.1+)
* iptables
* [uml-utilities](http://user-mode-linux.sourceforge.net/downloads.html)
* [mtools](https://www.gnu.org/software/mtools/)
* Ruby rake
* Ruby bundler
 

## Installation

```
git clone https://github.com/algolia/vagrant-uml.git
cd vagrant-uml
rake build
vagrant plugin install ./pkg/vagrant-uml-0.0.2.gem 
```

## Usage

The first step is adding a UML compatible vagrant box:

```
vagrant box add https://alg-archistore.s3.amazonaws.com/public/infra/vagrant/uml/xenial64/box_metadata-0.0.2.json
vagrant init algolia/uml/xenial64
vagrant up --provider uml
```

## Box format

An UML vagrant box is composed by the following elements:

* a runnable UML kernel named 'linux-SOMEVERSION'
* a filesystem image
* an info.json (optionnal) mentionning the author, the company and homepage
* a metadata.json file describing the box with the following information
  * the provider: "uml"
  * the box version
  * the rootfs file name stored in the box
  * the kernel version/suffix
  * a list of features provided by the kernel


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
