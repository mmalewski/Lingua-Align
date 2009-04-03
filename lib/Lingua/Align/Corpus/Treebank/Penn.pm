package Lingua::Align::Corpus::Treebank::Penn;

use 5.005;
use strict;

use Lingua::Align::Corpus::Treebank;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::Corpus::Treebank);
$VERSION = '0.01';

sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }

    return $self;
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

YADWA::Data::Trees::Penn - Perl extension for blah blah blah

=head1 SYNOPSIS

  use YADWA::Data::Trees::Penn;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for YADWA::Data::Trees::Penn, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Joerg Tiedemann, E<lt>tiedeman@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
