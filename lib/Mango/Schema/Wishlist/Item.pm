# $Id$
package Mango::Schema::Wishlist::Item;
use strict;
use warnings;

BEGIN {
    use base qw/DBIx::Class/;
    use DateTime ();
};

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('wishlist_item');
__PACKAGE__->source_name('WishlistItems');
__PACKAGE__->add_columns(
    id => {
        data_type         => 'UINT',
        is_auto_increment => 1,
        is_nullable       => 0
    },
    wishlist_id => {
        data_type         => 'UINT',
        is_auto_increment => 1,
        is_nullable       => 0,
        is_foreign_key    => 1
    },
    sku => {
        data_type      => 'VARCHAR',
        size           => 25,
        is_nullable    => 0,
    },
    quantity => {
        data_type      => 'TINYINT',
        size           => 3,
        is_nullable    => 0,
        default_value  => 1
    },
    description => {
        data_type     => 'VARCHAR',
        size          => 255,
        is_nullable   => 1,
        default_value => undef
    },
    created => {
        data_type     => 'DATETIME',
        is_nullable   => 0
    }
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(wishlist => 'Mango::Schema::Wishlist',
    {'foreign.id' => 'self.wishlist_id'}
);

1;
__END__
