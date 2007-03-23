package Mango::Web::Controller::Admin::Products;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Web::Base::Form/;
    use FormValidator::Simple::Constants;
    use Set::Scalar ();
};

=head1 NAME

Mango::Web::Controller::Admin::Products - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index 

=cut

sub index : PathPart('admin/products') Chained('/') Args(0) {
    my ($self, $c) = @_;
    $c->stash->{'template'} = 'admin/products/default';

    my $page = $c->request->param('page') || 1;
    my $products = $c->model('Products')->search(undef, {
        page => $page,
        rows => 2
    });

    $c->stash->{'products'} = $products;
    $c->stash->{'pager'} = $products->pager;
};

sub load : PathPart('admin/products') Chained('/') CaptureArgs(1) {
    my ($self, $c, $id) = @_;
    $c->stash->{'template'} = 'admin/products/edit';

    my $product = $c->model('Products')->get_by_id($id);

    if ($product) {
        $c->stash->{'product'} = $product;
    } else {
        $c->response->status(404);
        $c->detach;
    };
};

sub create : PathPart('admin/products/create') Chained('/') Args(0) {
    my ($self, $c) = @_;
    $c->stash->{'template'} = 'admin/products/create';

    my $form = $c->forward('form');

    ## I love being evil. I'll make plugins eventually, but I don't want
    ## the module clutter at the moment
    local *FormValidator::Simple::Validator::PRODUCT_UNIQUE = sub {
        return $c->model('Products')->get_by_sku($form->field('sku')) ? FALSE : TRUE;
    };

    if ($c->forward('submitted') && $c->forward('validate')) {
        my $product = $c->model('Products')->create({
            sku => $form->field('sku'),
            name => $form->field('name'),
            description => $form->field('description'),
            price => $form->field('price')
        });

        if (my $tags = $form->field('tags')) {
            $product->add_tags(split /,\s*/, $tags);
        };

        $c->response->redirect(
            $c->uri_for('/admin/products', $product->id, 'edit')
        );
    };
};

sub edit : PathPart('edit') Chained('load') Args(0) {
    my ($self, $c) = @_;
    $c->stash->{'template'} = 'admin/products/edit';

    my $product = $c->stash->{'product'};
    my @tags = $product->tags;
    my $form = $c->forward('form');

    ## I love being evil. I'll make plugins eventually, but I don't want
    ## the module clutter at the moment
    local *FormValidator::Simple::Validator::PRODUCT_UNIQUE = sub {
        if ($product->sku eq $form->field('sku')) {
            return TRUE;
        };
        my $existing = $c->model('Products')->get_by_sku($form->field('sku'));

        if ($existing && $existing->id != $product->id) {
            return FALSE;
        } else {
            return TRUE;
        };
    };

    $form->values({
        id          => $product->id,
        sku         => $product->sku,
        name        => $product->name,
        description => $product->description,
        price       => $product->price->value,
        tags        => join(', ', map {$_->name} @tags),
        created     => $product->created . ''
    });

    if ($c->forward('submitted') && $c->forward('validate')) {
        $product->name($form->field('name'));
        $product->sku($form->field('sku'));
        $product->description($form->field('description'));
        $product->price($form->field('price'));
        $product->update;

        if (my $tags = $form->field('tags')) {
            my $current_tags = Set::Scalar->new(map {$_->name} @tags);
            my $selected_tags = Set::Scalar->new(split /,\s*/, $tags);
            my $deleted_tags = $current_tags - $selected_tags;
            my $added_tags = $selected_tags - $current_tags;

            $product->add_tags($added_tags->members);
            $product->delete_tags({
                name => [$deleted_tags->members]
            });
        };

#        attributes  => [map {$_->name . ':' . $_->value} @attributes],
 #       foreach my $attribute ($form->field('attributes')) {
 #           my ($name, $value) = split /\s*:\s*/, $attribute;
 #           $product->add_attributes({
 #               name => $name, value => $value
 #           });
 #       };
    };
};



=head1 AUTHOR

A clever guy

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
