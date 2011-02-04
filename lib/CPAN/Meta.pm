use 5.006;
use strict;
use warnings;
use autodie;
package CPAN::Meta;
BEGIN {
  $CPAN::Meta::VERSION = '2.110350';
}
# ABSTRACT: the distribution metadata for a CPAN dist


use Carp qw(carp croak);
use CPAN::Meta::Feature;
use CPAN::Meta::Prereqs;
use CPAN::Meta::Converter;
use CPAN::Meta::Validator;
use Parse::CPAN::Meta 1.43 ();


BEGIN {
  my @STRING_READERS = qw(
    abstract
    description
    dynamic_config
    generated_by
    name
    release_status
    version
  );

  no strict 'refs';
  for my $attr (@STRING_READERS) {
    *$attr = sub { $_[0]{ $attr } };
  }
}


BEGIN {
  my @LIST_READERS = qw(
    author
    keywords
    license
  );

  no strict 'refs';
  for my $attr (@LIST_READERS) {
    *$attr = sub {
      my $value = $_[0]{ $attr };
      croak "$attr must be called in list context"
        unless wantarray;
      return @{ Storable::dclone($value) } if ref $value;
      return $value;
    };
  }
}

sub authors  { $_[0]->author }
sub licenses { $_[0]->license }


BEGIN {
  my @MAP_READERS = qw(
    meta-spec
    resources
    provides
    no_index

    prereqs
    optional_features
  );

  no strict 'refs';
  for my $attr (@MAP_READERS) {
    (my $subname = $attr) =~ s/-/_/;
    *$subname = sub {
      my $value = $_[0]{ $attr };
      return Storable::dclone($value) if $value;
      return {};
    };
  }
}


sub custom_keys {
  return grep { /^x_/i } keys %{$_[0]};
}

sub custom {
  my ($self, $attr) = @_;
  my $value = $self->{$attr};
  return Storable::dclone($value) if ref $value;
  return $value;
}


sub _new {
  my ($class, $struct, $options) = @_;
  my $self;

  if ( $options->{lazy_validation} ) {
    # try to convert to a valid structure; if succeeds, then return it
    my $cmc = CPAN::Meta::Converter->new( $struct );
    $self = $cmc->convert( version => 2 ); # valid or dies
    return bless $self, $class;
  }
  else {
    # validate original struct
    my $cmv = CPAN::Meta::Validator->new( $struct );
    unless ( $cmv->is_valid) {
      die "Invalid metadata structure. Errors: "
        . join(", ", $cmv->errors) . "\n";
    }
  }

  # up-convert older spec versions
  my $version = $struct->{'meta-spec'}{version} || '1.0';
  if ( $version == 2 ) {
    $self = $struct;
  }
  else {
    my $cmc = CPAN::Meta::Converter->new( $struct );
    $self = $cmc->convert( version => 2 );
  }

  return bless $self, $class;
}

sub new {
  my ($class, $struct, $options) = @_;
  my $self = eval { $class->_new($struct, $options) };
  croak($@) if $@;
  return $self;
}


sub create {
  my ($class, $struct, $options) = @_;
  my $version = __PACKAGE__->VERSION || 2;
  $struct->{generated_by} ||= __PACKAGE__ . " version $version" ;
  $struct->{'meta-spec'}{version} ||= int($version);
  my $self = eval { $class->_new($struct, $options) };
  croak ($@) if $@;
  return $self;
}


sub load_file {
  my ($class, $file, $options) = @_;
  $options->{lazy_validation} = 1 unless exists $options->{lazy_validation};

  croak "load_file() requires a valid, readable filename"
    unless -r $file;

  my $self;
  eval {
    my $struct = Parse::CPAN::Meta->load_file( $file );
    $self = $class->_new($struct, $options);
  };
  croak($@) if $@;
  return $self;
}


sub load_yaml_string {
  my ($class, $yaml, $options) = @_;
  $options->{lazy_validation} = 1 unless exists $options->{lazy_validation};

  my $self;
  eval {
    my ($struct) = Parse::CPAN::Meta->load_yaml_string( $yaml );
    $self = $class->_new($struct, $options);
  };
  croak($@) if $@;
  return $self;
}


sub load_json_string {
  my ($class, $json, $options) = @_;
  $options->{lazy_validation} = 1 unless exists $options->{lazy_validation};

  my $self;
  eval {
    my $struct = Parse::CPAN::Meta->load_json_string( $json );
    $self = $class->_new($struct, $options);
  };
  croak($@) if $@;
  return $self;
}


sub save {
  my ($self, $file, $options) = @_;

  my $version = $options->{version} || '2';

  if ( $version ge '2' ) {
    carp "'$file' should end in '.json'"
      unless $file =~ m{\.json$};
  }
  else {
    carp "'$file' should end in '.yml'"
      unless $file =~ m{\.yml$};
  }

  my $data = $self->as_string( $options );

  open my $fh, ">", $file;
  print {$fh} $data;
  close $fh;
}


# XXX Do we need this if we always upconvert? -- dagolden, 2010-04-14
sub meta_spec_version {
  my ($self) = @_;
  return $self->meta_spec->{version};
}


sub effective_prereqs {
  my ($self, $features) = @_;
  $features ||= [];

  my $prereq = CPAN::Meta::Prereqs->new($self->prereqs);

  return $prereq unless @$features;

  my @other = map {; $self->feature($_)->prereqs } @$features;

  return $prereq->with_merged_prereqs(\@other);
}


sub should_index_file {
  my ($self, $filename) = @_;

  for my $no_index_file (@{ $self->no_index->{file} || [] }) {
    return if $filename eq $no_index_file;
  }

  for my $no_index_dir (@{ $self->no_index->{directory} }) {
    $no_index_dir =~ s{$}{/} unless $no_index_dir =~ m{/\z};
    return if index($filename, $no_index_dir) == 0;
  }

  return 1;
}


sub should_index_package {
  my ($self, $package) = @_;

  for my $no_index_pkg (@{ $self->no_index->{package} || [] }) {
    return if $package eq $no_index_pkg;
  }

  for my $no_index_ns (@{ $self->no_index->{namespace} }) {
    return if index($package, "${no_index_ns}::") == 0;
  }

  return 1;
}


sub features {
  my ($self) = @_;

  my $opt_f = $self->optional_features;
  my @features = map {; CPAN::Meta::Feature->new($_ => $opt_f->{ $_ }) }
                 keys %$opt_f;

  return @features;
}


sub feature {
  my ($self, $ident) = @_;

  croak "no feature named $ident"
    unless my $f = $self->optional_features->{ $ident };

  return CPAN::Meta::Feature->new($ident, $f);
}


sub as_struct {
  my ($self, $options) = @_;
  my $backend = Parse::CPAN::Meta->json_backend();
  my $struct = $backend->new->decode(
    $backend->new->convert_blessed->encode($self)
  );
  if ( $options->{version} ) {
    my $cmc = CPAN::Meta::Converter->new( $struct );
    $struct = $cmc->convert( version => $options->{version} );
  }
  return $struct;
}


sub as_string {
  my ($self, $options) = @_;

  my $version = $options->{version} || '2';

  my $struct;
  if ( $self->version ne $version ) {
    my $cmc = CPAN::Meta::Converter->new( $self->as_struct );
    $struct = $cmc->convert( version => $version );
  }
  else {
    $struct = $self->as_struct;
  }

  my ($data, $backend);
  if ( $version ge '2' ) {
    $backend = Parse::CPAN::Meta->json_backend();
    $data = $backend->new->utf8->pretty->canonical->encode($struct);
  }
  else {
    $backend = Parse::CPAN::Meta->yaml_backend();
    $data = eval { no strict 'refs'; &{"$backend\::Dump"}($struct) };
    if ( $@ ) {
      croak $backend->can('errstr') ? $backend->errstr : $@
    }
  }

  return $data;
}

# Used by JSON::PP, etc. for "convert_blessed"
sub TO_JSON {
  return { %{ $_[0] } };
}

1;



=pod

=head1 NAME

CPAN::Meta - the distribution metadata for a CPAN dist

=head1 VERSION

version 2.110350

=head1 SYNOPSIS

  my $meta = CPAN::Meta->load_file('META.json');

  printf "testing requirements for %s version %s\n",
    $meta->name,
    $meta->version;

  my $prereqs = $meta->requirements_for('configure');

  for my $module ($prereqs->required_modules) {
    my $version = get_local_version($module);

    die "missing required module $module" unless defined $version;
    die "version for $module not in range"
      unless $prereqs->accepts_module($module, $version);
  }

=head1 DESCRIPTION

Software distributions released to the CPAN include a F<META.json> or, for
older distributions, F<META.yml>, which describes the distribution, its
contents, and the requirements for building and installing the distribution.
The data structure stored in the F<META.json> file is described in
L<CPAN::Meta::Spec>.

CPAN::Meta provides a simple class to represent this distribution metadata (or
I<distmeta>), along with some helpful methods for interrogating that data.

The documentation below is only for the methods of the CPAN::Meta object.  For
information on the meaning of individual fields, consult the spec.

=head1 METHODS

=head2 new

  my $meta = CPAN::Meta->new($distmeta_struct, \%options);

Returns a valid CPAN::Meta object or dies if the supplied metadata hash
reference fails to validate.  Older-format metadata will be up-converted to
version 2 if they validate against the original stated specification.

It takes an optional hashref of options. Valid options include:

=over

=item *

lazy_validation -- if true, new will attempt to convert the given metadata
to version 2 before attempting to validate it.  This means than any
fixable errors will be handled by CPAN::Meta::Converter before validation.
(Note that this might result in invalid optional data being silently
dropped.)  The default is false.

=back

=head2 create

  my $meta = CPAN::Meta->create($distmeta_struct, \%options);

This is same as C<new()>, except that C<generated_by> and C<meta-spec> fields
will be generated if not provided.  This means the metadata structure is
assumed to otherwise follow the latest L<CPAN::Meta::Spec>.

=head2 load_file

  my $meta = CPAN::Meta->load_file($distmeta_file, \%options);

Given a pathname to a file containing metadata, this deserializes the file
according to its file suffix and constructs a new C<CPAN::Meta> object, just
like C<new()>.  It will die if the deserialized version fails to validate
against its stated specification version.

It takes the same options as C<new()> but C<lazy_validation> defaults to
true.

=head2 load_yaml_string

  my $meta = CPAN::Meta->load_yaml_string($yaml, \%options);

This method returns a new CPAN::Meta object using the first document in the
given YAML string.  In other respects it is identical to C<load_file()>.

=head2 load_json_string

  my $meta = CPAN::Meta->load_json_string($json, \%options);

This method returns a new CPAN::Meta object using the structure represented by
the given JSON string.  In other respects it is identical to C<load_file()>.

=head2 save

  $meta->save($distmeta_file, \%options);

Serializes the object as JSON and writes it to the given file.  The only valid
option is C<version>, which defaults to '2'.

For C<version> 2 (or higher), the filename should end in '.json'.  L<JSON::PP>
is the default JSON backend. Using another JSON backend requires L<JSON> 2.5 or
later and you must set the C<$ENV{PERL_JSON_BACKEND}> to a supported alternate
backend like L<JSON::XS>.

For C<version> less than 2, the filename should end in '.yml'.
L<CPAN::Meta::Converter> is used to generate an older metadata structure, which
is serialized to YAML.  CPAN::Meta::YAML is the default YAML backend.  You may
set the C<$ENV{PERL_YAML_BACKEND}> to a supported alternative backend, though
this is not recommended due to subtle incompatibilities between YAML parsers
on CPAN.

=head2 meta_spec_version

This method returns the version part of the C<meta_spec> entry in the distmeta
structure.  It is equivalent to:

  $meta->meta_spec->{version};

=head2 effective_prereqs

  my $prereqs = $meta->effective_prereqs;

  my $prereqs = $meta->effective_prereqs( \@feature_identifiers );

This method returns a L<CPAN::Meta::Prereqs> object describing all the
prereqs for the distribution.  If an arrayref of feature identifiers is given,
the prereqs for the identified features are merged together with the
distribution's core prereqs before the CPAN::Meta::Prereqs object is returned.

=head2 should_index_file

  ... if $meta->should_index_file( $filename );

This method returns true if the given file should be indexed.  It decides this
by checking the C<file> and C<directory> keys in the C<no_index> property of
the distmeta structure.

C<$filename> should be given in unix format.

=head2 should_index_package

  ... if $meta->should_index_package( $package );

This method returns true if the given package should be indexed.  It decides
this by checking the C<package> and C<namespace> keys in the C<no_index>
property of the distmeta structure.

=head2 features

  my @feature_objects = $meta->features;

This method returns a list of L<CPAN::Meta::Feature> objects, one for each
optional feature described by the distribution's metadata.

=head2 feature

  my $feature_object = $meta->feature( $identifier );

This method returns a L<CPAN::Meta::Feature> object for the optional feature
with the given identifier.  If no feature with that identifier exists, an
exception will be raised.

=head2 as_struct

  my $copy = $meta->as_struct( \%options );

This method returns a deep copy of the object's metadata as an unblessed has
reference.  It takes an optional hashref of options.  If the hashref contains
a C<version> argument, the copied metadata will be converted to the version
of the specification and returned.  For example:

  my $old_spec = $meta->as_struct( {version => "1.4"} );

=head2 as_string

  my $string = $meta->as_string( \%options );

This method returns a serialized copy of the object's metadata.
reference.  It takes an optional hashref of options.  If the hashref contains
a C<version> argument, the copied metadata will be converted to the version
of the specification and returned.  For example:

  my $string = $meta->as_struct( {version => "1.4"} );

For C<version> greater than or equal to 2, the string will be serialized
as JSON.  For C<version> less than 2, the string will be serialized as YAML.
In both cases, the same rules are followed as in the C<save()> method for
choosing a serialization backend.

=head1 STRING DATA

The following methods return a single value, which is the value for the
corresponding entry in the distmeta structure.  Values should be either undef
or strings.

=over 4

=item *

abstract

=item *

description

=item *

dynamic_config

=item *

generated_by

=item *

name

=item *

release_status

=item *

version

=back

=head1 LIST DATA

These methods return lists of string values, which might be represented in the
distmeta structure as arrayrefs or scalars:

=over 4

=item *

authors

=item *

keywords

=item *

licenses

=back

The C<authors> and C<licenses> methods may also be called as C<author> and
C<license>, respectively, to match the field name in the distmeta structure.

=head1 MAP DATA

These readers return hashrefs of arbitrary unblessed data structures, each
described more fully in the specification:

=over 4

=item *

meta_spec

=item *

resources

=item *

provides

=item *

no_index

=item *

prereqs

=item *

optional_features

=back

=head1 CUSTOM DATA

A list of custom keys are available from the C<custom_keys> method and
particular keys may be retrieved with the C<custom> method.

  say $meta->custom($_) for $meta->custom_keys;

If a custom key refers to a data structure, a deep clone is returned.

=head1 BUGS

Please report any bugs or feature using the CPAN Request Tracker.
Bugs can be submitted through the web interface at
L<http://rt.cpan.org/Dist/Display.html?Queue=CPAN-Meta>

When submitting a bug or request, please include a test-file or a patch to an
existing test-file that illustrates the bug or desired feature.

=head1 SEE ALSO

=over 4

=item *

L<CPAN::Meta::Converter>

=item *

L<CPAN::Meta::Validator>

=back

=head1 AUTHORS

  David Golden <dagolden@cpan.org>
  Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by David Golden and Ricardo Signes.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__END__


