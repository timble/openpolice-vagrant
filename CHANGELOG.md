# Changelog

## 1.2.0 (5 May 2015)

- Fixed - Fix MailCatcher dependencies
- Improved - Upgraded to PHP 5.5
- Improved - Run composer from the root directory from now on
- Improved - Moved elasticsearch mapping files to /install/custom

## 1.1.0 (14 May 2014)

- Fixed - PHP-FPM should create the socket as user www-data.
- Added - Install Elasticsearch
- Added - Extended nginx config to include the _manager_ application
- Added - `police` installation script will now setup Elasticsearch mapping
- Improved - Box can now be installed using Vagrant Cloud using the `belgianpolice/box` identifier.
- Improved - Use Unix socket with PHP-FPM
- Added - README and CHANGELOG.

## 1.0.0 (5 September 2013):

* Setup basic Vagrantfile
* Add Puppet provisioning.
* Install and configure PHP, Nginx and MySQL
