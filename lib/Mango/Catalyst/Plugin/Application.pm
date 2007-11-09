# $Id$
package Mango::Catalyst::Plugin::Application;
use strict;
use warnings;
our $VERSION = $Mango::VERSION;

BEGIN {
    use base qw/
        Mango::Catalyst::Plugin::Authentication
        Mango::Catalyst::Plugin::I18N
        Mango::Catalyst::Plugin::Forms
        Catalyst::Plugin::Cache
        Catalyst::Plugin::Cache::Store::Memory
    /;
};

1;