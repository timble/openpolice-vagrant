README
======

Building the box
----------------

* Clone this repository.
* Install [VirtualBox](http://www.virtualbox.org/)
* Install [Vagrant](http://downloads.vagrantup.com/)
* Run `vagrant up`

```
    $ vagrant up
```

Repackaging the box
-----------------

Run purge.sh to reduce the VM size:

    $ sudo purge.sh
	
Ensure the police database is removed:

    $ mysqladmin -uroot -proot drop 9999
	
Create the package: 

    $ vagrant package --output=belgianpolice.box --vagrantfile Vagrantfile.pkg 

To test the new package locally, remove your current box and setup the local version:

    $ vagrant box remove belgianpolice/box
    $ vagrant box add /path/to/belgianpolice.box --name=belgianpolice/box
	
Go to your [Belgian Police Internet Platform](https://github.com/belgianpolice/internet-platform) clone and test: 

    $ cd /path/to/internet-platform
    $ vagrant destroy # if you've created the box before
    $ vagrant up
	
Share your box using [Vagrant Cloud](http://vagrantcloud.com)!