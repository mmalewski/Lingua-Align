package Lingua::Align::Corpus::Treebank;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::Corpus);
$VERSION = '0.01';

use Lingua::Align::Corpus;
use Lingua::Align::Corpus::Treebank::Penn;
use Lingua::Align::Corpus::Treebank::Stanford;
use Lingua::Align::Corpus::Treebank::TigerXML;
use Lingua::Align::Corpus::Treebank::AlpinoXML;


sub new{
    my $class=shift;
    my %attr=@_;

    if ($attr{-type}=~/tiger/i){
	return new Lingua::Align::Corpus::Treebank::TigerXML(%attr);
    }
    if ($attr{-type}=~/alpino/i){
	return new Lingua::Align::Corpus::Treebank::AlpinoXML(%attr);
    }
    if ($attr{-type}=~/stanford/i){
	return new Lingua::Align::Corpus::Treebank::Stanford(%attr);
    }
    return new Lingua::Align::Corpus::Treebank::Penn(%attr);
}


sub close{
    my $self=shift;
    my $file=shift || $self->{-file};
    $self->close_file($file);
}


# next sentence returns a tree for the next sentence
# (here: only virtual function ....)
sub read_next_sentence{}

sub next_sentence_id{}            # return next sentence ID and move to next
sub next_sentence_id_would_be{}   # return next sentence ID and stay at current


sub distance_to_root{
    my $self=shift;
    my ($tree,$node)=@_;
#    return 0 if (not defined $node);
#    return 0 if ($node eq '');
    if (exists $tree->{NODES}->{$node}->{TREELEVEL}){
	return $tree->{NODES}->{$node}->{TREELEVEL};
    }
    my $this=$node;
    my $count=0;
    while (exists $tree->{NODES}->{$this}->{PARENTS}){
	last if (scalar @{$tree->{NODES}->{$this}->{PARENTS}} == 0);
	$count++;
	$this=$tree->{NODES}->{$this}->{PARENTS}->[0];
	last if (not exists $tree->{NODES}->{$this});
    }
    $tree->{NODES}->{$node}->{TREELEVEL}=$count;
    return $count;
}

sub tree_size{
    my $self=shift;
    my $tree=shift;
    my $size=0;
    foreach my $n (keys %{$tree->{NODES}}){
	my $level=$self->distance_to_root($tree,$n);
	if ($level>$size){$size=$level;}
    }
    return $size;
}

sub get_all_leafs{
    my $self=shift;
    my ($tree,$attr)=@_;
    $attr = 'word' if (not defined $attr);
    my @words=();
    if (ref($tree->{TERMINALS}) eq 'ARRAY'){
	foreach my $n (@{$tree->{TERMINALS}}){
	    push(@words,$tree->{NODES}->{$n}->{$attr});
	}
    }
    return @words;
}

sub is_nonterminal{
    my $self=shift;
    my ($tree,$node)=@_;
    if (exists $tree->{NODES}){
	if (exists $tree->{NODES}->{$node}){
	    if (exists $tree->{NODES}->{$node}->{CHILDREN}){
		return 1;
	    }
	    if (exists $tree->{NODES}->{$node}->{CHILDREN2}){
		return 1;
	    }
	}
    }
    return 0;
}

sub is_terminal{
    my $self=shift;
    return not $self->is_nonterminal(@_);
}

 sub is_descendent{
    my $self=shift;
    my ($tree,$desc,$anc)=@_;
    my @parents=();
    if (exists $tree->{NODES}->{$desc}->{PARENTS}){
	@parents = @{$tree->{NODES}->{$desc}->{PARENTS}};
    }
    while (@parents){
	my $p=shift(@parents);
	return 1 if ($p eq $anc);
	if ($self->is_descendent($tree,$p,$anc)){
	    return 1;
	}
    }
    return 0;
}


sub is_ancestor{
    my $self=shift;
    my ($tree,$anc,$desc)=@_;
    return $self->is_descendent($tree,$desc,$anc);
}


# get all parents for a given node in a given tree

sub parents{
    my $self=shift;
    my ($tree,$node)=@_;
    if (exists $tree->{NODES}->{$node}->{PARENTS}){
	return @{$tree->{NODES}->{$node}->{PARENTS}};
    }
    return ();
}

# get (first) parent

sub parent{
    my $self=shift;
    my ($tree,$node)=@_;
    if (exists $tree->{NODES}->{$node}->{PARENTS}){
	return $tree->{NODES}->{$node}->{PARENTS}->[0];
    }
    return undef;
}

# get all children

sub children{
    my $self=shift;
    my ($tree,$node)=@_;
    if (exists $tree->{NODES}->{$node}->{CHILDREN}){
	return @{$tree->{NODES}->{$node}->{CHILDREN}};
    }
    return ();
}

# get all nodes in the subtree

sub subtree_nodes{
    my $self=shift;
    my ($tree,$node)=@_;
    my @subtree=();
    my @children=$self->children($tree,$node);
    foreach my $c (@children){
	push (@subtree,$c);
	push (@subtree,$self->subtree_nodes($tree,$c));
    }
    return @subtree;
}

# get all sister nodes

sub sisters{
    my $self=shift;
    my ($tree,$node)=@_;
    my @sisters=();
    if (exists $tree->{NODES}->{$node}->{PARENTS}){
	foreach my $p (@{$tree->{NODES}->{$node}->{PARENTS}}){
	    foreach my $s (@{$tree->{NODES}->{$p}->{CHILDREN}}){
		if ($node ne $s){
		    push(@sisters,$s);
		}
	    }
	}
    }
    return @sisters;
}


sub is_unary_subtree{
    my $self=shift;
    my ($tree,$node,$child)=@_;
    if (exists $tree->{NODES}){
	if (exists $tree->{NODES}->{$node}){
	    if (exists $tree->{NODES}->{$node}->{CHILDREN}){
		if ($#{$tree->{NODES}->{$node}->{CHILDREN}} == 0){
		    $$child = $tree->{NODES}->{$node}->{CHILDREN}->[0];
		    return 1;
		}
	    }
	}
    }
    return 0;
}

sub get_outside_leafs{
    my $self=shift;
    my ($tree,$node,$attr)=@_;
    $attr = 'word' if (not defined $attr);

    ## check if subtree leafs with the specified attr are already stored
    if (exists($tree->{NODES}->{$node}->{OUTLEAFS})){
	if (exists($tree->{NODES}->{$node}->{OUTLEAFS}->{$attr})){
	    if (ref($tree->{NODES}->{$node}->{OUTLEAFS}->{$attr}) eq 'ARRAY'){
		return @{$tree->{NODES}->{$node}->{OUTLEAFS}->{$attr}};
	    }
	}
	## if we have IDs --> get the attribute from the nodes
	elsif (exists($tree->{NODES}->{$node}->{OUTLEAFS}->{id})){
	    if (ref($tree->{NODES}->{$node}->{OUTLEAFS}->{id}) eq 'ARRAY'){
		my @ids = @{$tree->{NODES}->{$node}->{OUTLEAFS}->{id}};
		my @val=();
		foreach my $i (@ids){
		    push (@val,$tree->{NODES}->{$i}->{$attr});
		}
		return @val;
	    }
	}
    }

    my @leafs=@{$tree->{TERMINALS}};
    my @ids = $self->get_leafs($tree,$node,'id');

    my %inside=();
    foreach (@ids){$inside{$_}=1;}

    my @outside=();
    foreach (@leafs){
	if (!exists($inside{$_})){
	    push(@outside,$tree->{NODES}->{$_}->{$attr});
	}
    }
    ## cache this
    @{$tree->{NODES}->{$node}->{OUTLEAFS}->{$attr}}=@outside;
    return @outside;
}





sub get_leafs{
    my $self=shift;
    my ($tree,$node,$attr)=@_;
    return () if (ref($tree) ne 'HASH');
    return () if (ref($tree->{NODES}) ne 'HASH');

    $attr = 'word' if (not defined $attr);

    if (exists $tree->{NODES}->{$node}){

	## check if subtree leafs with the specified attr are already stored
	if (exists($tree->{NODES}->{$node}->{LEAFS})){
	    if (exists($tree->{NODES}->{$node}->{LEAFS}->{$attr})){
		if (ref($tree->{NODES}->{$node}->{LEAFS}->{$attr}) eq 'ARRAY'){
		    return @{$tree->{NODES}->{$node}->{LEAFS}->{$attr}};
		}
	    }
	    ## if we have IDs --> get the attribute from the nodes
	    elsif (exists($tree->{NODES}->{$node}->{LEAFS}->{id})){
		if (ref($tree->{NODES}->{$node}->{LEAFS}->{id}) eq 'ARRAY'){
		    my @ids = @{$tree->{NODES}->{$node}->{LEAFS}->{id}};
		    my @val=();
		    foreach my $i (@ids){
			push (@val,$tree->{NODES}->{$i}->{$attr});
		    }
		    return @val;
		}
	    }
	}

	## otherwise: go through all children
	if (exists $tree->{NODES}->{$node}->{CHILDREN}){
	    if (ref($tree->{NODES}->{$node}->{CHILDREN}) eq 'ARRAY'){
		my @leafs=();
		foreach my $c (@{$tree->{NODES}->{$node}->{CHILDREN}}){
		    push(@leafs,$self->get_leafs($tree,$c,$attr));
		}
		## cache subtree leafs ....
		@{$tree->{NODES}->{$node}->{LEAFS}->{$attr}}=@leafs;
		return @leafs;
	    }
	}
	else{
	    if (exists $tree->{NODES}->{$node}->{$attr}){
		return ($tree->{NODES}->{$node}->{$attr});
	    }
	    return ();
	}
    }
}


sub subtree_span{
    my $self=shift;
    my ($tree,$node)=@_;
    if (exists $tree->{NODES}->{$node}->{begin}){
	if (exists $tree->{NODES}->{$node}->{end}){
	    return ($tree->{NODES}->{$node}->{begin},
		    $tree->{NODES}->{$node}->{end});
	}
    }

    my @leafs = $self->get_leafs($tree,$node,'id');

    my %hash=();
    foreach (@leafs){$hash{$_}=1;}
    my $start=9999999;
    my $end=0;
    foreach (0..$#{$tree->{TERMINALS}}){
	if (exists $hash{$tree->{TERMINALS}->[$_]}){
	    if ($_<$start){$start = $_+1;}
	    if ($_>$end){$end = $_+1;}
	}
    }
    if ($start<9999999 && $end>0){
	$tree->{NODES}->{$node}->{begin} = $start;
	$tree->{NODES}->{$node}->{end} = $end;
	return ($start,$end);
    }
    return ();
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

YADWA::Data::Trees - Perl extension for blah blah blah

=head1 SYNOPSIS

  use YADWA::Data::Trees;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for YADWA::Data::Trees, created by h2xs. It looks like the
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
