package Lingua::Align::LinkSearch::AssignmentWellFormed;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::LinkSearch::Assignment);
$VERSION = '0.01';


sub search{
    my $self=shift;
    my ($linksST,$scores,$min_score,$src,$trg,$labels,
	$srctree,$trgtree,$linksTS)=@_;
    my ($correct,$wrong,$total) = $self->assign($linksST,$scores,$min_score,
						$src,$trg,$labels,
						$srctree,$trgtree,$linksTS);
    my %NotWell=();
    while ($self->check_wellformedness($srctree,$trgtree,$linksST,\%NotWell)){
    	my @sorted = sort { $NotWell{$a} <=> $NotWell{$b} } keys %NotWell;
    	my ($s,$t) = split(/\:/,$sorted[0]);
    	print STDERR "remove link $s --> $t\n";
    	delete $$linksST{$s}{$t};
    	if (not scalar keys %{$$linksST{$s}}){delete $$linksST{$s};}
    	delete $$linksTS{$t}{$s};
    	if (not scalar keys %{$$linksTS{$t}}){delete $$linksTS{$t};}
	%NotWell=();
    }

    $self->remove_already_linked($linksST,$linksTS,$scores,$src,$trg,$labels);

    my %LabelHash=();
    foreach (0..$#{$labels}){
	$LabelHash{$$src[$_]}{$$trg[$_]}=$$labels[$_];
    }
    ($correct,$wrong)=(0,0);
    foreach my $s (keys %{$linksST}){
	foreach my $t (keys %{$$linksST{$s}}){
	    if ($LabelHash{$s}{$t}){$correct++;}
	    else{$wrong++;}
	}
    }

    return ($correct,$wrong,$total);
}


sub check_wellformedness{
    my $self=shift;
    my ($srctree,$trgtree,$linksST,$NotWell)=@_;
    my $NrNotWell=0;
    foreach my $s (keys %{$linksST}){
	foreach my $t (keys %{$$linksST{$s}}){
	    if (not $self->is_wellformed($srctree,$trgtree,$s,$t,$linksST)){
		$$NotWell{"$s:$t"}=$$linksST{$s}{$t};
#		print STDERR "not wellformed: $s --> $t ($$linksST{$s}{$t})\n";
		$NrNotWell++;
	    }
	}
    }
    return $NrNotWell;
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
