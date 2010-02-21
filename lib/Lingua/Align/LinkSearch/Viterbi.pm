package Lingua::Align::LinkSearch::Viterbi;

use 5.005;
use strict;
use Lingua::Align::LinkSearch::GreedyWellFormed;
use Lingua::Align::Corpus::Treebank;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::LinkSearch::GreedyWellFormed);
$VERSION = '0.01';



sub search{
    my $self=shift;
    my ($linksST,$scores,$min_score,$src,$trg,$labels,
	$srctree,$trgtree,$linksTS)=@_;

    my $correct=0;
    my $wrong=0;
    my $total=0;

    my %value=();
    my %label=();
    foreach (0..$#{$scores}){
	if ($$scores[$_]>=$min_score){
	    $value{$$src[$_]}{$$trg[$_]}=$$scores[$_];
	    $label{$$src[$_]}{$$trg[$_]}=$$labels[$_];
	}
	if ($$labels[$_] == 1){$total++;}
    }
    if (ref($linksTS) ne 'HASH'){$linksTS={};}

    my $srcroot=$self->{TREES}->root_node($srctree);
    my $trgroot=$self->{TREES}->root_node($trgtree);

    my %link=();
    my %cost=();
    my $final = $self->align_nodes($srcroot,$trgroot,$srctree,$trgtree,\%value,
				   \%link,\%cost);

    # always align root nodes (good?)
    my $s = $srcroot;
    my $t = $trgroot;
    $$linksST{$s}{$t}=$value{$s}{$t};
    $$linksTS{$t}{$s}=$value{$s}{$t};
    if ($label{$s}{$t} == 1){$correct++;}
    else{$wrong++;}

    $self->read_links($srcroot,$trgroot,$srctree,
		      \%link,\%value,
		      $linksST,$linksTS,
		      \%label,\$correct,\$wrong);

#     my @c=$self->{TREES}->children($srctree,$s);
#     while (@c){
# 	foreach $s (@c){
# 	    $t = $link{$s}{$trgroot};
# 	    $$linksST{$s}{$t}=$value{$s}{$t};
# 	    $$linksTS{$t}{$s}=$value{$s}{$t};
# 	    if ($label{$s}{$t} == 1){$correct++;}
# 	    else{$wrong++;}
# 	    $trgroot = $t;
# 	}
#     }

    $self->remove_already_linked($linksST,$linksTS,$scores,$src,$trg,$labels);
    return ($correct,$wrong,$total);
}


sub read_links{
    my $self=shift;
    my ($srcroot,$trgroot,$srctree,$link,$value,
	$linksST,$linksTS,$label,$correct,$wrong)=@_;

    my @c=$self->{TREES}->children($srctree,$srcroot);
    foreach my $s (@c){
	if (exists $$link{$s} && ref($$link{$s}) eq 'HASH'){
	    if (exists $$link{$s}{$trgroot}){
		my $t = $$link{$s}{$trgroot};
		$$linksST{$s}{$t}=$$value{$s}{$t};
		$$linksTS{$t}{$s}=$$value{$s}{$t};
		if ($$label{$s}{$t} == 1){$$correct++;}
		else{$$wrong++;}
		$self->read_links($s,$t,$srctree,$link,$value,
				  $linksST,$linksTS,$label,
				  $correct,$wrong);
	    }
	}
    }
}

sub align_nodes{
    my $self=shift;
    my ($srcroot,$trgroot,$srctree,$trgtree,$value,$link,$cost,$indent)=@_;

    print STDERR "$indent-- subtree $srcroot:$trgroot\n";
    if (defined $$cost{$srcroot}){
	if (defined $$cost{$srcroot}{$trgroot}){
	    return $$value{$srcroot}{$trgroot};
	}
    }

    my $score=0;	
    foreach my $s ($self->{TREES}->children($srctree,$srcroot)){
	my ($BestScore,$BestNode)=(0,undef);
	# weak wellformedness: check alignment to target root
	my $score = $self->align_nodes($s,$trgroot,$srctree,$trgtree,
				       $value,$link,$cost,"$indent--");
	if ($score > $BestScore){
	    $BestScore=$score;
	    $BestNode=$trgroot;
	}
	foreach my $t ($self->{TREES}->subtree_nodes($trgtree,$trgroot)){
	    my $score = $self->align_nodes($s,$t,$srctree,$trgtree,
					   $value,$link,$cost,"$indent--");
	    if ($score > $BestScore){
		$BestScore=$score;
		$BestNode=$t;
	    }
	}
	if (defined $BestNode){
#	    $$link{$s}{"$srcroot:$trgroot"}=$BestNode;
#	    $$cost{$s}{"$srcroot:$trgroot"}=$BestScore;
	    $$link{$s}{$trgroot}=$BestNode;
	    $$cost{$s}{$trgroot}=$BestScore;
	    $score+=$BestScore;
	    print STDERR "$indent--....$s-->$BestNode ($BestScore)\n";
	}
#	else{
#	    print STDERR "no link found for source node $s!\n";
#	}
    }

    return $score+$$value{$srcroot}{$trgroot};
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
