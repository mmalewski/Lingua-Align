package Lingua::Align::Corpus;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw();
$VERSION = '0.01';

use FileHandle;
use Lingua::Align::Corpus::Treebank;
use Lingua::Align::Corpus::Factored;

sub new{
    my $class=shift;
    my %attr=@_;

    if (defined $attr{-type}){
	if ($attr{-type}=~/(tiger|penn|alpino)/i){
	    return new Lingua::Align::Corpus::Treebank(%attr);
	}
	elsif ($attr{-type}=~/factored/i){
	    delete $attr{-type};
	    return new Lingua::Align::Corpus::Factored(%attr);
	}
    }

    my $self={};
    bless $self,$class;

    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }
    $self->{-encoding} = $attr{-encoding} || 'utf8';

    return $self;
}


sub next_sentence{
    my $self=shift;
    my $words=shift;

    my $file=shift || $self->{-file};
    my $encoding=shift || $self->{-encoding};

    if (! defined $self->{FH}->{$file}){
	$self->{FH}->{$file} = new FileHandle;
	$self->{FH}->{$file}->open("<$file") || die "cannot open file $file\n";
	binmode($self->{FH}->{$file},":encoding($encoding)");
	$self->{SENT_COUNT}->{$file}=0;
    }
    my $fh=$self->{FH}->{$file};
    if (my $sent=<$fh>){
	chomp $sent;
	$self->{SENT_COUNT}->{$file}++;
	if ($sent=~/^\<s (snum|id)=\"?([^\"]+)\"?(\s|\>)/i){
	    $self->{SENT_ID}->{$file}=$2;
	}
	else{
	    $self->{SENT_ID}->{$file}=$self->{SENT_COUNT}->{$file};
	}
	$self->{LAST_SENT_ID}=$self->{SENT_ID}->{$file};
	$sent=~s/^\<s.*?\>\s*//;
	$sent=~s/\s*\<\/s.*?\>$//;
	@{$words}=split(/\s+/,$sent);
	return 1;
    }
    $fh->close;
    delete $self->{FH}->{$file};
    return 0;
}

sub current_id{
    my $self=shift;
    if ($_[0]){
	return $self->{SENT_ID}->{$_[0]};
    }
    return $self->{LAST_SENT_ID};
}


sub close_file{
    my $self=shift;
    my $file=shift;
    if (defined $self->{FH}){
	if (defined $self->{FH}->{$file}){
	    if (ref($self->{FH}->{$file})=~/FileHandle/){
		$self->{FH}->{$file}->close;
	    }
	}
    }
}	    

sub is_open{
    my $self=shift;
    my $file=shift;
    if (defined $self->{FH}){
	if (defined $self->{FH}->{$file}){
	    return 1;
	}
    }
    return 0;
}	    


sub close{
    my $self=shift;
    if (defined $self->{FH}){
	if (ref($self->{FH}) eq 'HASH'){
	    foreach my $f (keys %{$self->{FH}}){
		$self->close_file($f);
	    }
	}
    }
}



1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Lingua::Align::Corpus - Perl extension for reading a tokenized plain text corpus, 1 sentence per line

=head1 SYNOPSIS

  use Lingua::Align::Corpus;

  my $corpus = new Lingua::Align::Corpus(-file => $corpusfile);

  my @words=();
  while ($corpus->next_sentence(\@words)){
    print "\n",$corpus->current_id,"> ";
    print join(' ',@words);
  }

=head1 DESCRIPTION

=head1 SEE ALSO

=head1 AUTHOR

Joerg Tiedemann, E<lt>j.tiedemann@rug.nlE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
