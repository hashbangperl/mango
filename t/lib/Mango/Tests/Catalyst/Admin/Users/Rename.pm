# $Id: /local/CPAN/Mango/t/lib/Mango/Tests/Catalyst/Login/Rename.pm 1612 2008-05-22T02:02:53.243250Z claco  $
package Mango::Tests::Catalyst::Admin::Users::Rename;
use strict;
use warnings;

BEGIN {
    use base 'Mango::Tests::Catalyst::Admin::Users';

    use Test::More;
    use Path::Class ();
}

sub config_application {
    my $self = shift;

    my $cfile = Path::Class::file($self->application, 'lib', 'TestApp', 'Controller', 'Admin', 'Users.pm');
    my $ncfile = Path::Class::file($self->application, 'lib', 'TestApp', 'Controller', 'Admin', 'People.pm');
    my $contents = $cfile->slurp;
        
    $contents =~ s/package TestApp::Controller::Admin::Users;/package TestApp::Controller::Admin::People;/;

    $cfile->remove;
    $ncfile->openw->print($contents);
}

sub path {'admin/people'};

1;
