package Lingua::Align::LinkSearch::Intersection;

use 5.005;
use strict;
use vars qw($VERSION @ISA);
use Lingua::Align::LinkSearch::Src2Trg;
use Lingua::Align::LinkSearch::Trg2Src;

@ISA=qw(Lingua::Align::LinkSearch::Src2Trg Lingua::Align::LinkSearch::Trg2Src);
$VERSION = '0.01';


sub search{
    my $self=shift;
    my ($links,$scores,$min_score,$src,$trg,$labels)=@_;

    my %linksST=();
    my %linksTS=();
    my %LM=();         # matrix with correct labels
    
    my ($c1,$w1,$total1)=
     $self->searchSrc2Trg(\%linksST,$scores,$min_score,$src,$trg,$labels,\%LM);
    my ($c2,$w2,$total2)=
     $self->searchTrg2Src(\%linksTS,$scores,$min_score,$src,$trg,$labels);

    if ($total1 <=> $total2){
	print STDERR "strange: total is different for src2trg & trg2src\n";
    }

    my $correct=0;
    my $wrong=0;
#    my $missed=0;

    foreach my $s (keys %linksST){
	foreach my $t (keys %{$linksST{$s}}){
	    if (exists $linksTS{$t}){
		if (exists $linksTS{$t}{$s}){
		    if ($linksST{$s}{$t}>=$min_score){
			$$links{$s}{$t}=$linksST{$s}{$t};
			if ($LM{$s}{$t} == 1){$correct++;}
			else{$wrong++;}
		    }
		}
#		elsif ($LM{$s}{$t} == 1){$missed++;}
	    }
#	    elsif ($LM{$s}{$t} == 1){$missed++;}
	}
    }
    return ($correct,$wrong,$total1);
}




1;
__END__

=head1 NAME

YADWA - Perl modules for Yet Another Discriminative Word Aligner

=head1 SYNOPSIS

  use YADWA;

=head1 DESCRIPTION

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Joerg Tiedemann, E<lt>j.tiedemanh@rug.nl@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
