package Lingua::Align::Corpus::Parallel::STA;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::Corpus::Parallel);
$VERSION = '0.01';

use FileHandle;
use File::Basename;

use XML::Parser;
use Lingua::Align::Corpus::Parallel;


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


sub read_next_alignment{
    my $self=shift;
    my ($srctree,$trgtree,$links)=@_;

    my $file=$_[3] || $self->{-alignfile};

    # first: read all tree alignments (problem for large parallel treebanks?!)
    if ((! ref($self->{SRC})) || (! ref($self->{TRG}))){
	$self->read_tree_alignments($file);
    }

    return 0 if (not $self->{SRC}->next_sentence($srctree));
    return 0 if (not $self->{TRG}->next_sentence($trgtree));


    # if the current trees are not linked: read more trees
    # 1) no links defined for current source sentence! --> read more src
    while (not exists $self->{__XMLHANDLE__}->{SALIGN}->{$$srctree{ID}}){
	print STDERR "skip source $$srctree{ID}\n" if ($self->{-verbose});
	return 0 if (not $self->{SRC}->next_sentence($srctree));
    }
    # 2) target sentence is not linked to current source sentence
    if ($$trgtree{ID} ne $self->{__XMLHANDLE__}->{SALIGN}->{$$srctree{ID}}){
	my $thisID=$$trgtree{ID};
	my $linkedID=$self->{__XMLHANDLE__}->{SALIGN}->{$$srctree{ID}};
	$thisID=~s/^[^0-9]*//;
	$linkedID=~s/^[^0-9]*//;
	# assume that sentence IDs are ordered upwards
	while ($thisID<$linkedID){
	    return 0 if (not $self->{TRG}->next_sentence($trgtree));
	    $thisID=$$trgtree{ID};
	    $thisID=~s/^[^0-9]*//;
	}
    }
    # still not the one?
    # 3) source sentence is not linked to current target sentence
    if ($$trgtree{ID} ne $self->{__XMLHANDLE__}->{SALIGN}->{$$srctree{ID}}){
	my $thisID=$$srctree{ID};
	my $linkedID=$self->{__XMLHANDLE__}->{TALIGN}->{$$trgtree{ID}};
	$thisID=~s/^[^0-9]*//;
	$linkedID=~s/^[^0-9]*//;
	# assume that sentence IDs are ordered upwards
	while ($thisID<$linkedID){
	    return 0 if (not $self->{SRC}->next_sentence($srctree));
	    $thisID=$$srctree{ID};
	    $thisID=~s/^[^0-9]*//;
	}
    }
    # ... that's all I can do ....


    # this would be all links in the entire corpus:
    #    $$links = $self->{__XMLHANDLE__}->{LINKS};

    # return only links from current tree pair!
    $$links=$self->{__XMLHANDLE__}->{NLINKS}->{"$$srctree{ID}:$$trgtree{ID}"};

    return 1;

}


sub get_links{
    my $self=shift;
    my ($src,$trg)=@_;

    my $alllinks = $_[2] || $self->{__XMLHANDLE__}->{LINKS};

    my %links=();

    foreach my $sn (keys %{$$src{NODES}}){
	if (exists $$alllinks{$sn}){
	    foreach my $tn (keys %{$$trg{NODES}}){
		if (exists $$alllinks{$sn}{$tn}){
		    if ($$alllinks{$sn}{$tn} ne 'comment'){
			$links{$sn}{$tn} = $$alllinks{$sn}{$tn};
		    }
		}
	    }
	}
    }
    return %links;
}


# print tree alignments
# - SrcId, TrgId = treebank IDs (default: src & trg)
# - add link probablility in comment

sub print_alignments{
    my $self=shift;
    my $srctree=shift;
    my $trgtree=shift;
    my $links=shift;

    my $SrcId = shift || 'src';
    my $TrgId = shift || 'trg';

    my $str='';
    foreach my $s (keys %{$links}){
	foreach my $t (keys %{$$links{$s}}){
	    my $att="author=\"Lingua::Align\" prob=\"$$links{$s}{$t}\"";

#	    my $att="comment=\"None\"";
	    # P<0.5 --> fuzzy link?!?
	    if ($$links{$s}{$t}>0.5){
		$str.="    <align $att type=\"good\">\n";
	    }
	    else{
		$str.="    <align $att type=\"fuzzy\">\n";
	    }
#	    $str.="    <align $att type=\"auto\">\n";
	    $str.="      <node node_id=\"$s\" treebank_id=\"$SrcId\"/>\n";
	    $str.="      <node node_id=\"$t\" treebank_id=\"$TrgId\"/>\n";
	    $str.="    </align>\n";
	}
    }
    return $str;
}

sub print_header{
    my $self=shift;
    my ($srcfile,$trgfile,$srcid,$trgid)=@_;
    my $string = "<?xml version=\"1.0\" ?>\n<treealign>\n  <treebanks>\n";
    $string.="    <treebank filename=\"$srcfile\" id=\"$srcid\"/>\n";
    $string.="    <treebank filename=\"$trgfile\" id=\"$trgid\"/>\n";
    $string.="  </treebanks>\n  <alignments>\n";
    return $string;
}

sub print_tail{
    my $self=shift;
    return "  </alignments>\n</treealign>\n";
}


sub read_tree_alignments{
    my $self=shift;
    my $file=shift;
    my $links=shift;

    if (! defined $self->{FH}->{$file}){
	$self->{FH}->{$file} = new FileHandle;
	$self->{FH}->{$file}->open("<$file") || die "cannot open file $file\n";
	$self->{__XMLPARSER__} = new XML::Parser(Handlers => 
						 {Start => \&__XMLTagStart,
						  End => \&__XMLTagEnd});
	$self->{__XMLHANDLE__} = $self->{__XMLPARSER__}->parse_start;

	# swap sentencee alignments
	if ($self->{-swap_alignment}){
	    $self->{__XMLHANDLE__}->{SWAP_ALIGN}=1;
	}
    }

    my $fh=$self->{FH}->{$file};
    my $OldDel=$/;
    $/='>';
    while (<$fh>){
	eval { $self->{__XMLHANDLE__}->parse_more($_); };
	if ($@){
	    warn $@;
	    print STDERR $_;
	}
    }
    $/=$OldDel;
    $fh->close;

    my $srcid = $self->{__XMLHANDLE__}->{TREEBANKIDS}->[0];
    my $trgid = $self->{__XMLHANDLE__}->{TREEBANKIDS}->[1];

    my %attr=();
    $attr{-src_type}='TigerXML';
    $attr{-trg_type}='TigerXML';
    $attr{-src_file}=
	__find_corpus_file($self->{__XMLHANDLE__}->{TREEBANKS}->{$srcid},$file);
    $attr{-trg_file}=
	__find_corpus_file($self->{__XMLHANDLE__}->{TREEBANKS}->{$trgid},$file);

    $self->make_corpus_handles(%attr);
    if (ref($links)){
	$$links = $self->{__XMLHANDLE__}->{LINKS};
    }

    return $self->{__XMLHANDLE__}->{LINKCOUNT};
}



sub treebankID{
    my $self=shift;
    my $nr=shift || 0;
    if (exists $self->{__XMLHANDLE__}){
	if (exists $self->{__XMLHANDLE__}->{TREEBANKIDS}){
	    if (ref($self->{__XMLHANDLE__}->{TREEBANKIDS}) eq 'ARRAY'){
		return $self->{__XMLHANDLE__}->{TREEBANKIDS}->[$nr];
	    }
	}
    }
    return $nr+1;
#    return undef;
}

sub src_treebankID{
    my $self=shift;
    return $self->treebankID(0);
}

sub trg_treebankID{
    my $self=shift;
    return $self->treebankID(1);
}

sub src_treebank{
    my $self=shift;
    my $id=$self->src_treebankID();
    if (defined $id){
	if (ref($self->{__XMLHANDLE__}->{TREEBANKS}) eq 'HASH'){
	    return $self->{__XMLHANDLE__}->{TREEBANKS}->{$id};
	}
	else{
	    return $self->{-src_file};
	}
    }
    return undef;
}

sub trg_treebank{
    my $self=shift;
    my $id=$self->trg_treebankID();
    if (defined $id){
	if (ref($self->{__XMLHANDLE__}->{TREEBANKS}) eq 'HASH'){
	    return $self->{__XMLHANDLE__}->{TREEBANKS}->{$id};
	}
	else{
	    return $self->{-trg_file};
	}
    }
    return undef;
}


sub __find_corpus_file{
    my ($file,$alignfile)=@_;
    return $file if (-e $file);
    my $dir = dirname($alignfile);
    return $dir.'/'.$file if (-e $dir.'/'.$file);
    my $base=basename($file);
    return $dir.'/'.$base if (-e $dir.'/'.$base);
    if ($file!~/\.gz$/){
	return __find_corpus_file($file.'.gz',$alignfile);
    }
    warn "cannot find file $file\n";
    return $file;
}



##-------------------------------------------------------------------------
## 

sub __XMLTagStart{
    my ($p,$e,%a)=@_;

    if ($e eq 'treebanks'){
	$p->{TREEBANKIDS}=[];
    }
    elsif ($e eq 'treebank'){
	$p->{TREEBANKS}->{$a{id}}=$a{filename};
	push (@{$p->{TREEBANKIDS}},$a{id});
    }
    elsif ($e eq 'align'){
	$p->{ALIGN}->{type}=$a{type};
	$p->{ALIGN}->{prob}=$a{prob} if (exists $a{prob});
	$p->{ALIGN}->{comment}=$a{comment} if (exists $a{comment});
    }
    elsif ($e eq 'node'){
	$p->{ALIGN}->{$a{treebank_id}}=$a{node_id}; # (always 1 node/id?)
    }
}

sub __XMLTagEnd{
    my ($p,$e)=@_;
    
    if ($e eq 'align'){
	# we assume that there are only two treebansk linked with each other
	my $src=$p->{ALIGN}->{$p->{TREEBANKIDS}->[0]};
	my $trg=$p->{ALIGN}->{$p->{TREEBANKIDS}->[1]};
	$p->{LINKS}->{$src}->{$trg}=$p->{ALIGN}->{type};
	$p->{LINKCOUNT}++;
	# assume that node IDs include sentence ID
	# assume also that there are only 1:1 sentence alignments
	my ($sid)=split(/\_/,$src);
	my ($tid)=split(/\_/,$trg);
	$p->{SALIGN}->{$sid}=$tid;
	$p->{TALIGN}->{$tid}=$sid;
	# node links per tree pair
	if (exists $p->{ALIGN}->{prob}){
	    $p->{NLINKS}->{"$sid:$tid"}->{$src}->{$trg}=$p->{ALIGN}->{prob};
	}
	else{
	    $p->{NLINKS}->{"$sid:$tid"}->{$src}->{$trg}=$p->{ALIGN}->{type};
	}
    }
    elsif ($e eq 'treebanks'){
	if ($p->{SWAP_ALIGN}){           # swap alignment direction
	    print STDERR "swap alignment direction!\n";
	    my $src = $p->{TREEBANKIDS}->[0];
	    $p->{TREEBANKIDS}->[0] = $p->{TREEBANKIDS}->[1];
	    $p->{TREEBANKIDS}->[1] = $src;
	}
	$p->{NEWTREEBANKINFO}=1;
    }
}





1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

YADWA::Data::Aligned::STA - Perl extension for blah blah blah

=head1 SYNOPSIS

  use YADWA::Data::Aligned::STA;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for YADWA::Data::Aligned::STA, created by h2xs. It looks like the
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
