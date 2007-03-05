# $Id$
package Mango::Provider::DBIC;
use strict;
use warnings;

BEGIN {
    use base qw/Mango::Provider/;
    use Scalar::Util ();
    use DateTime ();
    use Mango::Iterator ();
    use Mango::Exception qw/:try/;

    __PACKAGE__->mk_group_accessors('component_class', qw/schema_class/);
    __PACKAGE__->mk_group_accessors('inherited', qw/
        source_name
        connection_info
        _resultset
        _schema
    /);

    *DBIx::Class::Row::get_inflated_columns = sub {
        my $self = shift;

        return map {$_ => $self->$_} $self->columns;
    };
};
__PACKAGE__->schema_class('Mango::Schema');

sub resultset {
    my $self = shift;

    if (!$self->_resultset) {
        if (!$self->source_name) {
            throw Mango::Exception('SCHEMA_SOURCE_NOT_SPECIFIED');
        };

        try {
            $self->_resultset($self->schema->resultset($self->source_name));
        } except {
            throw Mango::Exception('SCHEMA_SOURCE_NOT_FOUND', $self->source_name);
        };
    };

    return $self->_resultset;
};

sub schema {
    my $self = shift;

    if (!$self->schema_class) {
        throw Mango::Exception('SCHEMA_CLASS_NOT_SPECIFIED');
    };

    if (!$self->_schema) {
        $self->_schema(
            $self->schema_class->connect(@{$self->connection_info || []})
        );
    };

    return $self->_schema;
};

sub create {
    my ($self, $data) = @_;
    my $result = $self->resultset->create($data);

    return $self->result_class->new({
        provider => $self,
        data => {$result->get_inflated_columns}
    });
};

sub search {
    my ($self, $filter, $options) = @_;

    $filter  ||= {};
    $options ||= {};

    my $resultset = $self->resultset->search($filter, $options);
    my @results = map {
        $self->result_class->new({
            provider => $self,
            data => {$_->get_inflated_columns}
        })
    } $resultset->all;

    if (wantarray) {
        return @results;
    } else {
        return Mango::Iterator->new({
            provider => $self,
            data => \@results,
            pager => $options->{'page'} ? $resultset->pager : undef
        });
    };
};

sub update {
    my ($self, $object) = @_;

    $object->updated(DateTime->now);

    return $self->resultset->find($object->id)->update(
        {%{$object->data}}
    );
};

sub delete {
    my ($self, $filter) = @_;

    if (Scalar::Util::blessed $filter) {
        $filter = {id => $filter->id};
    } elsif (ref $filter ne 'HASH') {
        $filter = {id => $filter};
    };

    return $self->resultset->search($filter)->delete_all;
};

1;
__END__
