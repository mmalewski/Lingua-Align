package Lingua::Align::Corpus::Treebank::AlpinoXML;

use 5.005;
use strict;
use Lingua::Align::Corpus::Treebank;
use Lingua::Align::Corpus::Treebank::TigerXML;


use vars qw($VERSION @ISA);
$VERSION = '0.01';
@ISA = qw(Lingua::Align::Corpus::Treebank::TigerXML);

use FileHandle;
use XML::Parser;



sub read_index{
    my $self=shift;
    my $corpus=shift;
    $corpus=~s/\.data(\.[dg]z)?//;
    my $index=$corpus.'.index';
    if (-e $index){
	if (open F,"<$index"){
	    while (<F>){
		chomp;
		my ($id,$start,$length)=split(/\s+/);
		$id=~s/\.xml//;
		my $longid=$id;
		my $base=$corpus;
		if ($id=~/^(.*)\-([^\-]+)$/){
		    $base = $1;
		    $id = $2;
	    }
		push (@{$self->{SENT_ID}},$id);
		push (@{$self->{SENT_LONGID}},$longid);
	    }
	    close F;
	}
	else{
	    warn "cannot open index file for $corpus\n";
	}
    }
}

sub next_sentence_id_would_be{
    my $self=shift;
    my $offset=shift;
    if (ref($self->{SENT_ID}) eq 'ARRAY'){
	if ($self->{NEXT_SENT}+$offset <= $#{$self->{SENT_ID}}){
	    return $self->{SENT_ID}->[$self->{NEXT_SENT}+$offset];
	}
	return 'EOF';
    }
    return $self->{NEXT_SENT}+$offset+1;
}


sub read_next_sentence{
    my $self=shift;
    my $tree=shift;

    my $file=shift || $self->{-file};
    if (! defined $self->{FH}->{$file}){
	$self->{FH}->{$file} = new FileHandle;
	if ($file=~/\.[dg]z$/){
	    $self->{FH}->{$file}->open("gzip -cd <$file |") || 
		die "cannot open file $file\n";
	}
	else{
	    $self->{FH}->{$file}->open("<$file") || 
		die "cannot open file $file\n";
	}
	$self->{__XMLPARSER__} = new XML::Parser(Handlers => 
						 {Start => \&__XMLTagStart,
						  End => \&__XMLTagEnd,
						  Char => \&__XMLChar});
	$self->{__XMLHANDLE__} = $self->{__XMLPARSER__}->parse_start;
	$self->{__FIRST_SENTENCE__}=1;
	$self->read_index($file);
	$self->{NEXT_SENT}=0;
    }

    my $sentid = $self->next_sentence_id_would_be();
    $self->{__XMLHANDLE__}->{SENTID}=$sentid;
    delete $self->{__XMLHANDLE__}->{SENT};

    my $fh=$self->{FH}->{$file};
    my $OldDel=$/;
    $/='>';
    while (<$fh>){

	## parse XML header only for first sentence
	## add global root node before first tag
	## end of sentence if not at the beginning of the file
	if (/\<\?xml\s+version.*\?\>/){
	    last if (not $self->{__FIRST_SENTENCE__});
	    delete $self->{__FIRST_SENTENCE__};
	    $_.='<DocRoot>';
	}

	eval { $self->{__XMLHANDLE__}->parse_more($_); };
	if ($@){
	    warn $@;
	    print STDERR $_;
	}
    }
    $/=$OldDel;
    if (defined $self->{__XMLHANDLE__}->{SENT}){
	$tree->{ROOTNODE}=$self->{__XMLHANDLE__}->{ROOTNODE};
	$tree->{NODES}=$self->{__XMLHANDLE__}->{NODES};

	# sort terminals by position (ID)!!!!!!!!
	@{$tree->{TERMINALS}}=sort @{$self->{__XMLHANDLE__}->{TERMINALS}};

	if ($self->{__XMLHANDLE__}->{SENTID}=~/^(.*)\-([^-]+)$/){
	    $tree->{ID}=$2;
	    $tree->{CORPUS}=$1;
	    $tree->{LONGID}=$self->{__XMLHANDLE__}->{SENTID};
	}
	else{
	    $tree->{ID}=$self->{__XMLHANDLE__}->{SENTID};
	}
	$self->{NEXT_SENT}++;
	return 1;
    }
    $self->close_file($file);
    return 0;
}




##-------------------------------------------------------------------------
## 


sub __XMLTagStart{
    my ($p,$e,%a)=@_;

    if ($e eq 'alpino_ds'){
	$p->{NODES}={};        # need better clean-up?! (memory leak?)
	$p->{TERMINALS}=[];
	$p->{INDEX}={};
	delete $p->{ROOTNODE};
	delete $p->{CURRENT};
    }
    elsif ($e eq 'node'){

	$a{id}=$p->{SENTID}.'_'.$a{id};      # append sentence ID to node ID

	if (exists $a{word}){
	    $a{id}=500+$a{begin};            # start terminal nodes with 500
	    $a{id}=$p->{SENTID}.'_'.$a{id};  # and the begin position!!
	    push(@{$p->{TERMINALS}},$a{id});
	}
	foreach (keys %a){
	    $p->{NODES}->{$a{id}}->{$_}=$a{$_};
	}

	# save indeces ...
	if (exists $a{index}){
	    push(@{$p->{INDEX}->{$a{index}}},$a{id});
	}
	if (exists $p->{CURRENT}){
	    my $parent=$p->{CURRENT};
	    push(@{$p->{NODES}->{$a{id}}->{PARENTS}},$parent);
	    push(@{$p->{NODES}->{$parent}->{CHILDREN}},$a{id});
#	    push(@{$p->{NODES}->{$a{id}}->{RELATION}},$a{rel});
	    push(@{$p->{NODES}->{$parent}->{RELATION}},$a{rel});
	}
	$p->{CURRENT}=$a{id};
	if (not exists $p->{ROOTNODE}){
	    $p->{ROOTNODE}=$a{id};
	}
    }
#    elsif ($e eq 'sentence'){
#    }
    elsif ($e eq 'comment'){
	$p->{__COMMENT__}=1;
    }
}

sub __XMLTagEnd{
    my ($p,$e)=@_;

    if ($e eq 'node'){
	my $id = $p->{CURRENT};
	if (exists $p->{NODES}->{$id}->{PARENTS}){
	    $p->{CURRENT} = $p->{NODES}->{$id}->{PARENTS}->[0];
	}
	else{
	    delete $p->{CURRENT};
	}
    }
    elsif ($e eq 'comment'){
	delete $p->{__COMMENT__};
    }

    elsif ($e eq 'alpino_ds'){

	# solve index links ...
	my %add=();
	foreach my $i (keys %{$p->{INDEX}}){
	    foreach my $n1 (@{$p->{INDEX}->{$i}}){
		foreach my $n2 (@{$p->{INDEX}->{$i}}){
		    next if ($n1 eq $n2);

		    # if n1 has children
		    # --> add them to n2 as well!
		    # if n1 is a terminal node
		    # --> add child to n2!

		    if (exists $p->{NODES}->{$n1}->{CHILDREN}){
			@{$add{$n2}}=@{$p->{NODES}->{$n1}->{CHILDREN}};
		    }
		    elsif (exists $p->{NODES}->{$n1}->{word}){
			@{$add{$n2}}=($n1);
		    }
		}
	    }
	}

	# add links to children as collected above
	# (this could probably be simplified ...)

	foreach my $n (keys %add){
#	    print STDERR "add ";
#	    print STDERR join(' ',@{$add{$n}});
#	    print STDERR " to $n\n";
	    push(@{$p->{NODES}->{$n}->{CHILDREN2}},@{$add{$n}});
	    foreach my $c (@{$add{$n}}){
		push(@{$p->{NODES}->{$n}->{RELATION2}},
		     $p->{NODES}->{$n}->{rel});
	    }

	}
	
    }
}

sub __XMLChar{
    my ($p,$s)=@_;

    if (exists $p->{__COMMENT__}){
	if ($s=~/Q\#(.*?)\|/){
	    $p->{SENT}=$1;
	}
#	my ($sid)=split(/\|/,$s);
#	$sid=~s/^.*?\#//;
#	$p->{SENTID}=$sid;
    }
}





# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

YADWA::Data::Trees::TigerXML - Perl extension for blah blah blah

=head1 SYNOPSIS

  use YADWA::Data::Trees::TigerXML;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for YADWA::Data::Trees::TigerXML, created by h2xs. It looks like the
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
