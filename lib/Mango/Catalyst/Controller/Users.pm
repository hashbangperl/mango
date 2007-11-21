# $Id$
package Mango::Catalyst::Controller::Users;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Catalyst::Controller/;
    use Mango ();
    use Path::Class ();
    
    __PACKAGE__->form_directory(
        Path::Class::Dir->new(Mango->share, 'forms', 'users')
    );
};

=head2 COMPONENT

=cut

sub COMPONENT {
    my $self = shift->NEXT::COMPONENT(@_);

    $self->register_namespace('users');

    return $self;
};

=head2 index

=cut

sub index : Chained PathPrefix Args(0) ActionClass('REST') Template('users/index') {
    my ($self, $c) = @_;
    my $users = $c->model('Users')->search(undef, {
        page => $self->current_page,
        rows => $self->entries_per_page
    });
    my $pager = $users->pager;

    $c->stash->{'users'} = $users;
    $c->stash->{'pager'} = $pager;

    if ($self->wants_browser) {
        ## keep REST from going to _GET
        $c->detach;
    };

    return;
};

=head2 index_GET

=cut

sub index_GET : Private {
    my ($self, $c) = @_;
    my $users = $c->stash->{'users'};
    my $pager = $c->stash->{'pager'};

    my @users = map {
        {id => $_->id, username => $_->username}
    } $users->all;

    $self->entity({
        users => \@users
    }, $pager);

    return;
};

=head2 index_POST

=cut

sub index_POST : Private {
    my ($self, $c) = @_;

    if (my $user = $c->authenticate && $c->is_admin) {

    } else {
        $c->unauthorized;
    };

    return;
};

=head2 instance

=cut

sub instance : Chained PathPrefix CaptureArgs(1) {
    my ($self, $c, $id) = @_;
    my $user = $c->model('Users')->search({
        username => $id
    })->first;

    if ($user) {
        my $profile = $c->model('Profiles')->search({
            user => $user
        })->first;

        $c->stash->{'user'} = $user;
        $c->stash->{'profile'} = $profile;
    } else {
        $c->response->status(404);
        $c->detach;
    };
};

=head2 create

=cut

sub create : Local Template('users/create') {
    my ($self, $c) = @_;
    my $form = $self->form;
    my @roles = $c->model('Roles')->search;

    $form->field('roles', options => [map {[$_->id, $_->name]} @roles]);

    $form->unique('username', sub {
        return !$c->model('Users')->search({
            username => $form->field('username')
        })->count;
    });

    if ($self->submitted && $self->validate->success) {
        my $user = $c->model('Users')->create({
            username => $form->field('username'),
            password => $form->field('password')
        });

        my $profile = $c->model('Profiles')->create({
            user_id => $user->id,
            first_name => $form->field('first_name'),
            last_name  => $form->field('last_name')
        });

        foreach my $role ($form->field('roles')) {
            $c->model('Roles')->add_user($role, $user);
        };

        $c->response->redirect(
            $c->uri_for($self->action_for('update'), [$user->username]) . '/'
        );
    };
};

=head2 update

=cut

sub update : Chained('instance') PathPart Args(0) Template('users/update') {
    my ($self, $c) = @_;
    my $user = $c->stash->{'user'};
    my $profile = $c->stash->{'profile'};
    my @membership = $c->model('Roles')->search({
        user => $user
    });
    my @roles = $c->model('Roles')->search;
    my $form = $self->form;

    $form->field('roles', options => [map {[$_->id, $_->name]} @roles]);
    $form->values({
        id               => $user->id,
        username         => $user->username,
        password         => $user->password,
        confirm_password => $user->password,
        created          => $user->created . '',
        updated          => $user->updated . '',
        first_name       => $profile->first_name,
        last_name        => $profile->last_name,
        
        ## for some reason FB is wonky about no selected multiples compared to values
        ## yet it get's empty fields correct against non multiple values
        roles            => $c->request->method eq 'GET' ? [map {$_->id} @membership] : []
    });

    $c->stash->{'roles'} = $c->model('Roles')->search;
    $c->stash->{'user_roles'} = $c->model('Roles')->search({
        user => $user
    });

    if ($self->submitted && $self->validate->success) {
        my $current_roles = Set::Scalar->new(map {$_->id} @membership);
        my $selected_roles = Set::Scalar->new($form->field('roles'));
        my $deleted_roles = $current_roles - $selected_roles;
        my $added_roles = $selected_roles - $current_roles;

        $user->password($form->field('password'));
        $user->update;

        $form->values({
            updated     => $user->updated . ''
        });

        $profile->first_name($form->field('first_name'));
        $profile->last_name($form->field('last_name'));
        $profile->update;

        if ($deleted_roles->size) {
            map {
                $c->model('Roles')->remove_users($_, $user)
            } $deleted_roles->members;
        };

        if ($added_roles->size) {
            map {
                $c->model('Roles')->add_users($_, $user)
            } $added_roles->members;
        };
    };
};

=head2 delete

=cut

sub delete : Chained('load') PathPart Args(0) Template('users/delete') {
    my ($self, $c) = @_;
    my $form = $self->form;
    my $user = $c->stash->{'user'};

    if ($self->submitted && $self->validate->success) {
        if ($form->field('id') == $user->id) {

            ## remove from all roles
            map {
                $_->remove_user($user);
            } $c->model('Roles')->search({
                user => $user
            });

            ## delete profile
            $c->model('Profiles')->delete({
                user => $user
            });

            ## delete wishlists
            $c->model('Wishlists')->delete({
                user => $user
            });

            ## delete carts
            $c->model('Carts')->delete({
                user => $user
            });

            ## delete user
            $user->destroy;

            $c->res->redirect(
                $c->uri_for($self->action_for('index')) . '/'
            );
        } else {
            $c->stash->{'errors'} = ['ID_MISTMATCH'];
        };
    };
};




























#
#=head2 index_POST
#
#Creates a new user.
#
#=cut
#
#sub index_POST : Form('create') {
#    my ($self, $c) = @_;
#
#    if ($self->wants_browser) {
#        
#    } else {
#        if (my $user = $c->authenticate) {
#            warn $self->form;
#        } else {
#            $c->unauthorized;
#        };
#    };
#};

1;