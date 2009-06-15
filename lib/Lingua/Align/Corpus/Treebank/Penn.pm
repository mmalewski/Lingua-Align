package Lingua::Align::Corpus::Treebank::Penn;

use 5.005;
use strict;

use Lingua::Align::Corpus::Treebank;
use File::Basename;

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

sub next_sentence_id{
    my $self=shift;

    if ($self->{NO_SENTID_FILE}){
	$self->{SENTCOUNT}++;
	return $self->{SENTCOUNT};
    }

    my $file=shift || $self->{-id_file};
    if (! defined $self->{FH}->{$file}){
	if (not defined $file){
	    my $base=basename($self->{-file});
	    my $dir=dirname($self->{-file});
	    $base=~s/\..*$/.ids/;
	    if (-e $dir.'/text/'.$base){
		$file=$dir.'/text/'.$base;
	    }
	    elsif (-e $dir.'/text/'.$base.'.gz'){
		$file=$dir.'/text/'.$base.'.gz';
	    }
	    else{
		$self->{NO_SENTID_FILE}=1;
	    }
	    $self->{-id_file}=$file;
	    return $self->next_sentence_id();
	}
	else{
	    $self->{FH}->{$file} = $self->open_file($file);
	}
    }

    my $fh=$self->{FH}->{$file};
    my $id = <$fh>;
    chomp $id;

    if ($id=~/^(.*)\-([^-]+)$/){
	return $2;
    }
    return $id;
}


sub read_next_sentence{
    my $self=shift;
    my $tree=shift;
    %{$tree}=();

    my $file=shift || $self->{-file};
    if (! defined $self->{FH}->{$file}){
	$self->{FH}->{$file} = $self->open_file($file);
	$self->{-file}=$file;
    }
    my $fh=$self->{FH}->{$file};

    $self->__initialize_parser($tree);
    $tree->{ID}=$self->next_sentence_id();

    # look for a possible tree start
    while(<$fh>){
	$_=<$fh>;
	last if (/^\s*\(/)
    }

    # parse until first empty line
    if (defined $_){
	do {
	    $self->__parse($_,$tree);
	    $_=<$fh>;
	}
	until ($_!~/\S/);
	return 1;
    }
    return 0;

#    while (<$fh>){
#	chomp;
#	next if ($_!~/\S/);
#	return 1 if ($self->__parse($_,$tree));
#    }

    return 0;
}

sub __initialize_parser{
    my $self=shift;
    $self->{OPEN_BRACKETS}=0;
    $self->{NODECOUNT}=0;
    delete $self->{CURRENTNODE};
}

sub __parse{
    my $self=shift;
    my ($string,$tree)=@_;

    while ($string=~/\S/){

	# terminal node!
	if ($string=~/^\s*\((\S+)\s+(\S+?)\)(.*)$/){
	    my ($pos,$word)=($1,$2);
	    if ($word eq '-RRB-'){$word=')';}        # brackets
	    elsif ($word eq '-LRB-'){$word='(';}
	    $string=$3;

	    $self->{NODECOUNT}++;
	    my $node = 500+$self->{NODECOUNT};
	    $node=$tree->{ID}.'_'.$node;
	    $tree->{NODES}->{$node}->{pos} = $pos;
	    $tree->{NODES}->{$node}->{word} = $word;
	    $tree->{NODES}->{$node}->{id} = $node;
	    push(@{$tree->{TERMINALS}},$node);

	    my $parent = $self->{CURRENTNODE};
	    push(@{$tree->{NODES}->{$node}->{PARENTS}},$parent);
	    push(@{$tree->{NODES}->{$parent}->{CHILDREN}},$node);
#	    push(@{$tree->{NODES}->{$node}->{RELATION}},'--');
	    push(@{$tree->{NODES}->{$parent}->{RELATION}},'--');

	}

	elsif ($string=~/^\s*\((\S+)(.*)$/){
	    my $cat=$1;
	    $string=$2;

	    $self->{NODECOUNT}++;
	    $self->{OPEN_BRACKETS}++;
	    my $node = $self->{NODECOUNT};
	    $node=$tree->{ID}.'_'.$node;
	    $tree->{NODES}->{$node}->{cat} = $cat;
	    $tree->{NODES}->{$node}->{id} = $node;

	    if ($self->{NODECOUNT} == 1){
		if ($cat!~/ROOT/){
		    print '';
		}
		$tree->{ROOTNODE} = $node;
	    }
	    else{
		my $parent = $self->{CURRENTNODE};
		push(@{$tree->{NODES}->{$node}->{PARENTS}},$parent);
		push(@{$tree->{NODES}->{$parent}->{CHILDREN}},$node);
#		push(@{$tree->{NODES}->{$node}->{RELATION}},'--');
		push(@{$tree->{NODES}->{$parent}->{RELATION}},'--');
	    }

	    $self->{CURRENTNODE} = $node;

	}

	elsif ($string=~/^\s*\)(.*)$/){
	    $string=$1;
	    my $node = $self->{CURRENTNODE};
	    my $parent = $tree->{NODES}->{$node}->{PARENTS}->[0];
	    $self->{CURRENTNODE}=$parent;
	    $self->{OPEN_BRACKETS}--;
	}

	# something is wrong!
	elsif ($string=~/\S/){
	    return 0;
	}

    }

    return 1 if ($self->{OPEN_BRACKETS} == 0);
    return 0;

}



sub print_tree{
    my $self=shift;
    my $tree=shift;

    my $ids=shift || [];
    my $node = shift || $tree->{ROOTNODE};

    my $string.='(';
    if (defined $tree->{NODES}->{$node}->{cat}){
	$string.=$tree->{NODES}->{$node}->{cat};
    }
    elsif (defined $tree->{NODES}->{$node}->{pos}){
	$string.=$tree->{NODES}->{$node}->{pos};
    }
    elsif (defined $tree->{NODES}->{$node}->{rel}){
	$string.=$tree->{NODES}->{$node}->{rel};
    }
    # add node ID if necessary (for Dublin aligner format)
    if ($self->{-add_ids}){
	if (not $self->{-skip_node_ids}){
	    $string.='-'.$tree->{NODES}->{$node}->{id};
	}
	my $idx = scalar @{$ids} + 1;
	$string.='-'.$idx;
	$tree->{NODES}->{$node}->{idx}=$idx;
    }
    push (@{$ids},$tree->{NODES}->{$node}->{id});
    $string.=' ';

    if (exists $tree->{NODES}->{$node}->{CHILDREN}){
	foreach my $c (@{$tree->{NODES}->{$node}->{CHILDREN}}){
	    $string.=$self->print_tree($tree,$ids,$c);
	}
    }

    elsif (defined $tree->{NODES}->{$node}->{word}){
	$string.=$tree->{NODES}->{$node}->{word};
    }
    elsif (defined $tree->{NODES}->{$node}->{index}){
#	my $child = $tree->{NODES}->{$node}->{CHILDREN2}->[0];
	$string.='index-'.$tree->{NODES}->{$node}->{CHILDREN2}->[0];
    }
    $string.=')';
    return $string;
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
