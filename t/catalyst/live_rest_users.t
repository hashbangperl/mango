#!perl -w
# $Id$
use strict;
use warnings;

BEGIN {
    use lib 't/lib';
    use Test::More;
    
    use Mango::Test ();

    plan skip_all => 'No REST for the wicked.';
    Mango::Test->mk_app;
};


## GET /users
{
    my $m = Test::WWW::Mechanize::Catalyst->new;


    ## REST using friendly view name
    my $r = $m->get('/users/?view=yaml');
    is($r->code, 200);
    is($r->header('Content-Type'), 'text/x-yaml');
    is_deeply(YAML::Load($r->content), {
        users => [
            {id => 1, username => 'admin'}
        ],
        current_page => 1,
        entries_per_page => 10,
        total_entries => 1,
        first_page => 1,
        last_page => 1
    });

    ## REST using content-type param
    $r = $m->get('/users/?content-type=text/x-yaml');
    is($r->code, 200);
    is($r->header('Content-Type'), 'text/x-yaml');
    is_deeply(YAML::Load($r->content), {
        users => [
            {id => 1, username => 'admin'}
        ],
        current_page => 1,
        entries_per_page => 10,
        total_entries => 1,
        first_page => 1,
        last_page => 1
    });

    ## REST using Content-Type header
    $m->add_header('Content-Type', 'text/x-yaml');
    $r = $m->get('/users/');
    is($r->code, 200);
    is($r->header('Content-Type'), 'text/x-yaml');
    is_deeply(YAML::Load($r->content), {
        users => [
            {id => 1, username => 'admin'}
        ],
        current_page => 1,
        entries_per_page => 10,
        total_entries => 1,
        first_page => 1,
        last_page => 1
    });
};


## POST /users
{
    my $m = Test::WWW::Mechanize::Catalyst->new;

    ## access denied for anonymous users using view
    my $r = $m->post('/users/?view=yaml');
    is($r->code, 401);
    is($r->header('Content-Type'), 'text/x-yaml');
    is($r->content, YAML::Dump(undef));

    ## access denied for anonymous users using view
    $r = $m->post('/users/?content-type=text/x-yaml');
    is($r->code, 401);
    is($r->header('Content-Type'), 'text/x-yaml');
    is($r->content, YAML::Dump(undef));

    ## access denied for anonymous users using Content-Type
    $m->add_header('Content-Type', 'text/x-yaml');
    $r = $m->post('/users/');
    is($r->code, 401);
    is($r->header('Content-Type'), 'text/x-yaml');
    is($r->content, YAML::Dump(undef));

    ## successful post using view
    $m = Test::WWW::Mechanize::Catalyst->new;
    $m->credentials('admin', 'admin');
    $r = $m->post('/users/?view=yaml', Content => "---\nfoo: bar\nboo:\n  - 1\n  - 2\n", Content_Type => 'text/x-json');
    is($r->code, 201);
    is($r->header('Content-Type'), 'text/x-yaml');
    is($r->content, YAML::Dump(undef));
};
