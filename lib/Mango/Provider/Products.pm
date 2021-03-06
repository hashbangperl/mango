# $Id$
package Mango::Provider::Products;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Provider::DBIC/;
    use Mango::Exception ();
    use Scalar::Util     ();
    use DateTime         ();

    __PACKAGE__->mk_group_accessors( 'component_class',
        qw/attribute_class tag_class/ );
    __PACKAGE__->mk_group_accessors( 'inherited',
        qw/attribute_source_name tag_source_name/ );
}
__PACKAGE__->attribute_class('Mango::Attribute');
__PACKAGE__->attribute_source_name('ProductAttributes');
__PACKAGE__->tag_class('Mango::Tag');
__PACKAGE__->tag_source_name('Tags');
__PACKAGE__->result_class('Mango::Product');
__PACKAGE__->source_name('Products');

sub get_by_sku {
    my ( $self, $sku ) = @_;

    return $self->search( { sku => $sku } )->first;
}

sub search {
    my ( $self, $filter, $options ) = @_;

    $filter  ||= {};
    $options ||= {};

    if ( my $tags = delete $filter->{'tags'} ) {
        my $count;

        if ( @{$tags} ) {
            foreach my $tag ( @{$tags} ) {
                if ( Scalar::Util::blessed $tag) {
                    if ( $tag->isa('Mango::Tag') ) {
                        $tag = $tag->name;
                    } else {
                        Mango::Exception->throw('NOT_A_TAG');
                    }
                }

                if ( !$count ) {
                    $count = 1;
                    $filter->{'tag.name'} = $tag;
                } else {
                    $filter->{ 'tag_' . $count . '.name' } = $tag;
                }
                $count++;
            }

            $options->{'distinct'} = 1;
            if ( defined $options->{'join'} ) {
                if (  !ref $options->{'join'}
                    || ref $options->{'join'} eq 'HASH' )
                {
                    $options->{'join'} = [ $options->{'join'} ];
                }
            } else {
                $options->{'join'} = [];
            }
            push @{ $options->{'join'} },
              map { { 'map_product_tag' => 'tag' } } @{$tags};
        }
    }

    return $self->SUPER::search( $filter, $options );
}

sub create {
    my ( $self, $data ) = ( shift, shift );
    my $attributes = delete $data->{'attributes'};
    my $tags       = delete $data->{'tags'};
    my $product    = $self->SUPER::create( $data, @_ );

    if ($attributes) {
        $product->add_attributes( @{$attributes} );
    }
    if ($tags) {
        $product->add_tags( @{$tags} );
    }

    return $product;
}

sub add_attribute {
    my @attributes = shift->add_attributes(@_);

    return shift @attributes;
}

sub add_attributes {
    my ( $self, $product, @data ) = @_;
    my $resultset = $self->schema->resultset( $self->attribute_source_name );
    my @added;

    if ( Scalar::Util::blessed($product) ) {
        if ( $product->isa('Mango::Product') ) {
            $product = $product->id;
        } else {
            Mango::Exception->throw('NOT_A_PRODUCT');
        }
    }

    foreach my $attribute (@data) {
        if ( Scalar::Util::blessed $attribute) {
            if ( $attribute->isa('Mango::Attribute') ) {
                $attribute = { $attribute->get_columns };
            } else {
                Mango::Exception->throw('NOT_A_ATTRIBUTE');
            }
        }
        $attribute->{'product_id'} = $product;

        push @added, $self->attribute_class->new(
            {
                $resultset->update_or_create( $attribute,
                    { key => 'product_attribute_name' } )
                  ->get_inflated_columns,
                meta => {
                    provider => $self,
                    parent   => $product
                }
            }
        );
    }

    return @added;
}

sub search_attributes {
    my ( $self, $product, $filter, $options ) = @_;

    $filter  ||= {};
    $options ||= {};

    if ( Scalar::Util::blessed($product) ) {
        if ( $product->isa('Mango::Product') ) {
            $product = $product->id;
        } else {
            Mango::Exception->throw('NOT_A_PRODUCT');
        }
    }

    $filter->{'product_id'} = $product;

    my $resultset =
      $self->schema->resultset( $self->attribute_source_name )
      ->search( $filter, $options );
    my @results = map {
        $self->attribute_class->new(
            {
                $_->get_inflated_columns,
                meta => {
                    provider => $self,
                    parent   => $product
                }
            }
          )
    } $resultset->all;

    if (wantarray) {
        return @results;
    } else {
        return Mango::Iterator->new(
            {
                data  => \@results,
                pager => $options->{'page'} ? $resultset->pager : undef
            }
        );
    }
}

sub delete_attributes {
    my ( $self, $product, $filter ) = @_;
    my $resultset = $self->schema->resultset( $self->attribute_source_name );

    $filter ||= {};

    if ( Scalar::Util::blessed($product) ) {
        if ( $product->isa('Mango::Product') ) {
            $product = $product->id;
        } else {
            Mango::Exception->throw('NOT_A_PRODUCT');
        }
    }

    $filter->{'product_id'} = $product;

    return $resultset->search($filter)->delete_all;
}

sub update_attribute {
    my ( $self, $attribute ) = @_;
    my $resultset = $self->schema->resultset( $self->attribute_source_name );
    my $updated_column = $self->updated_column;

    $attribute->$updated_column( DateTime->now );

    return $resultset->find( $attribute->id )
      ->update( { $attribute->get_columns } );
}

sub add_tag {
    my @tags = shift->add_tags(@_);

    return shift @tags;
}

sub add_tags {
    my ( $self, $product, @data ) = @_;
    my $resultset = $self->schema->resultset( $self->tag_source_name );
    my @added;

    if ( Scalar::Util::blessed($product) ) {
        if ( $product->isa('Mango::Product') ) {
            $product = $product->id;
        } else {
            Mango::Exception->throw('NOT_A_PRODUCT');
        }
    }

    foreach my $tag (@data) {
        if ( Scalar::Util::blessed $tag) {
            if ( $tag->isa('Mango::Tag') ) {
                $tag = { $tag->get_columns };
            } else {
                Mango::Exception->throw('NOT_A_TAG');
            }
        } elsif ( !ref $tag ) {
            $tag = { name => $tag };
        }

        if ( !$tag->{'name'} ) {
            next;
        }

        my $newtag = $resultset->find_or_create($tag);
        $newtag->related_resultset('map_product_tag')->find_or_create(
            {
                product_id => $product,
                tag_id     => $newtag->id
            }
        );
        push @added, $self->tag_class->new(
            {
                $newtag->get_inflated_columns,
                meta => {
                    provider => $self,
                    parent   => $product
                }
            }
        );
    }

    return @added;
}

sub search_tags {
    my ( $self, $product, $filter, $options ) = @_;

    $filter  ||= {};
    $options ||= {};

    if ( Scalar::Util::blessed($product) ) {
        if ( $product->isa('Mango::Product') ) {
            $product = $product->id;
        } else {
            Mango::Exception->throw('NOT_A_PRODUCT');
        }
    }

    $filter->{'products'} = { 'id' => $product };

    return $self->tags( $filter, $options );
}

sub delete_tags {
    my ( $self, $product, $filter ) = @_;
    my $resultset = $self->schema->resultset( $self->tag_source_name );

    $filter ||= {};

    if ( Scalar::Util::blessed($product) ) {
        if ( $product->isa('Mango::Product') ) {
            $product = $product->id;
        } else {
            Mango::Exception->throw('NOT_A_PRODUCT');
        }
    }

    return $resultset->search($filter)->related_resultset('map_product_tag')
      ->search( { 'product_id' => $product } )->delete_all;
}

sub tags {
    my ( $self, $filter, $options ) = @_;

    $filter  ||= {};
    $options ||= {};

    my $pfilter = delete $filter->{'products'} || {};

    foreach my $key ( keys %{$pfilter} ) {
        next if $key =~ /^me\./;
        $pfilter->{"me.$key"} = delete $pfilter->{$key};
    }
    foreach my $key ( keys %{$filter} ) {
        next if $key =~ /^tag\./;
        $pfilter->{"tag.$key"} = delete $filter->{$key};
    }

    $options->{'group_by'} =
      [ 'tag.id', 'tag.name', 'tag.created', 'tag.updated' ];
    $options->{'+select'} = [ { 'count' => 'tag.name' } ];
    $options->{'+as'} = ['count'];

    my @results =    ## no critic
      $self->resultset->search($pfilter)->related_resultset('map_product_tag')
      ->related_resultset('tag')->search( $filter, $options )->all;

    my @tags = map {
        $self->tag_class->new(
            {
                $_->get_inflated_columns,
                count => $_->get_column('count'),
                meta  => { provider => $self }
            }
          )
    } @results;

    if (wantarray) {
        return @tags;
    } else {
        return Mango::Iterator->new( { data => \@tags } );
    }
}

sub related_tags {
    my ( $self, $filter, $options ) = @_;

    $filter               ||= {};
    $options              ||= {};
    $filter->{'products'} ||= {};

    my $tags = delete $filter->{'tags'} || [];
    my @ids =
      map { $_->id }
      $self->search( { tags => $tags }, { select => 'me.id' } )->all;

    my @results;
    if (@ids) {
        $filter->{'products'}->{'id'} = \@ids;
        $filter->{'tag.name'} = [ -and => map { { '!=' => $_ } } @{$tags} ];
        @results = $self->tags( $filter, $options )->all;
    }

    if (wantarray) {
        return @results;
    } else {
        return Mango::Iterator->new( { data => \@results } );
    }
}

1;
__END__

=head1 NAME

Mango::Provider::Products - Provider class for product information

=head1 SYNOPSIS

    my $provider = Mango::Provider::Products->new;
    my $product = $provider->get_by_id(23);

=head1 DESCRIPTION

Mango::Provider::Products is the provider class responsible for creating,
deleting, updating and searching product information, including product
tags and attributes.

=head1 CONSTRUCTOR

=head2 new

=over

=item Arguments: \%options

=back

Creates a new product provider object. If options are passed to new, those are
sent to C<setup>.

    my $provider = Mango::Provider::Products->new;

See L<Mango::Provider/new> and L<Mango::Provider::DBIC/new> for a list of
other possible options.

=head1 METHODS

=head2 add_attributes

=over

=item Arguments: $product, @attributes

=back

Adds the specified attributes to the specified product. C<product> can be a
Mango::Product object or a product id. C<attributes> can be a list of
attribute data hashes or Mango::Attribute objects.

    $provider->add_attributes(23, {name => 'Attribute', value => 'Value'}, $attributeobect, ...)

=head2 add_attribute

Same as C<add_attributes>.

=head2 add_tags

=over

=item Arguments: $product, @tags

=back

Adds the specified tags to the specified product. C<product> can be a
Mango::Product object or a product id. C<tags> can be a list of tag strings
or Mango::Tag objects.

    $provider->add_tags(23, 'computer', $tagobect, ...)

=head2 add_tag

Same as C<add_tags>.

=head2 create

=over

=item Arguments: \%data

=back

Creates a new Mango::Product object using the supplied data.

    my $product = $provider->create({
        sku => 'ABC-1234',
        price =>  2.34,
        description => 'The best product ever'
    });
    
    print $role->name;

In addition to using the column names, the following special keys are
available:

=over

=item attributes

This can be an anonymous array containing Mango::Attribute objects or hashes
of attribute data (or both):

    my $product = $provider->create({
        sku => 'ABC-1234',
        price =>  2.34,
        description => 'The best product ever',
        attributes => [
            {name => 'Attribute1', value => 'Value1'},
            $attributeobject
        ]
    });

=item tags

This can be an anonymous array containing Mango::Tag objects or tag strings
(or both):

    my $product = $provider->create({
        sku => 'ABC-1234',
        price =>  2.34,
        description => 'The best product ever',
        tags => [
            qw/computer linux/,
            $tagobject
        ]
    });

=back

=head2 delete

=over

=item Arguments: \%filter

=back

Deletes products from the provider matching the supplied filter.

    $provider->delete({
        id => 23
    });

In addition to using the column names, the following special keys are
available:

=over

=item user

This can be a user id, or a user object for which this profile is assigned to.

    $provider->delete({
        user => $user
    });

It is recommended that you use this key, rather than setting the foreign key
column manually in case it changes later.

=back

=head2 delete_attributes

=over

=item Arguments: $product, $filter

=back

Deletes attributes matching the specified filter form the specified product.
C<product> can be a Mango::Product object or a product id.

    $provider->delete_attributes(23, {name => 'AttributeName'});

=head2 delete_tags

=over

=item Arguments: $product, $filter

=back

Deletes tags matching the specified filter form the specified product.
C<product> can be a Mango::Product object or a product id.

    $provider->delete_tags(23, {name => [qw/computer linux/]});

=head2 get_by_id

=over

=item Arguments: $id

=back

Returns a Mango::Product object matching the specified id.

    my $product = $provider->get_by_id(23);

Returns undef if no matching product can be found.

=head2 get_by_sku

=over

=item Arguments: $sku

=back

Returns a Mango::PRoduct object matching the specified id.

    my $product = $provider->get_by_sku('ABC-1234');

Returns undef if no matching product can be found.

=head2 search

=over

=item Arguments: \%filter, \%options

=back

Returns a list of Mango::Product objects in list context, or a Mango::Iterator
in scalar context matching the specified filter.

    my @products = $provider->search({
        sku => 'A%'
    });
    
    my $iterator = $provider->search({
        sku => 'A%'
    });

In addition to using the column names, the following special keys are
available:

=over

=item tags

This can be an anonymous array containing Mango::Tag objects or tag strings
(or both):

    my $products = $provider->search({
        sku => 'A%',
        tags => [
            'computer',
            $tagobject
        ]
    });

=back

See L<DBIx::Class::Resultset/ATTRIBUTES> for a list of other possible options.

=head2 search_attributes

=over

=item Arguments: $product, $filter, $options

=back

Returns a list of Mango::Attribute objects in list context, or a
Mango::Iterator in scalar context matching the specified filter.

    $provider->search_attributes(23, {name => 'A'%});

=head2 search_tags

=over

=item Arguments: $product, $filter, $options

=back

Returns a list of Mango::Tag objects in list context, or a Mango::Iterator
in scalar context matching the specified filter.

    $provider->search_tags(23, {name => [qw/computer linux/]});

=head2 tags

Returns a list of Mango::Tag objects in list context, or a Mango::Iterator
in scalar context matching the specified filter.

    my $tags = $provider->tags;

Only tags that are assigned to at least on product are returned. In addition
to using the column names, the following special keys are available:

=over

=item products

This is a hash containing a filter applied against products before returning
those products tags.

    my $tags = $provider->tags({
        products => {
            sku => 'A%'
        }
    });

=back

=head2 related_tags

=over

=item Arguments: \%filter

=back

Returns a list or iterator of tags related to the specified products/tags,
excluding the already selected tags.

=head2 update

=over

=item Arguments: $product

=back

Sets the 'updated' column to DateTime->now and saves any changes made to the
product back to the underlying store.

    my $product = $provider->create(\%data);
    $product->price(10.95);
    
    $provider->update($product);

=head2 update_attribute

=over

=item Arguments: $attribute

=back

Sets the 'updated' column to DateTime->now and saves any changes made to the
product back to the underlying store.

    $attribute->value('AttributeValue');
    
    $provider->update_attribute($attribute);

=head1 SEE ALSO

L<Mango::Provider>, L<Mango::Provider::DBIC>, L<Mango::Product>,
L<Mango::Tag>, L<Mango::Attribute>, L<DBIx::Class>

=head1 AUTHOR

    Christopher H. Laco
    CPAN ID: CLACO
    claco@chrislaco.com
    http://today.icantfocus.com/blog/
