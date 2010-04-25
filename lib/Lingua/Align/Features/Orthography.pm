package Lingua::Align::Features::Orthography;

use 5.005;
use strict;
use utf8;

use vars qw($VERSION @ISA);
use vars qw(%__LCSR_CACHE $__LCSR_CACHE_SIZE $__LCSR_CACHE_COUNT);

@ISA = qw(Lingua::Align::Features::Tree);
$VERSION = '0.01';

$__LCSR_CACHE_COUNT=0;
$__LCSR_CACHE_SIZE=1000000;



sub get_features{
    my $self=shift;
    my ($src,$trg,$srcN,$trgN,$FeatTypes,$values)=@_;

    my @srcwords = $self->{TREES}->get_leafs($src,$srcN);
    my $srcstr = join(' ',@srcwords);
    my @trgwords = $self->{TREES}->get_leafs($trg,$trgN);
    my $trgstr = join(' ',@trgwords);

    my $srclen=length($srcstr);
    my $trglen=length($trgstr);


    $self->string_sim_features($srcstr,$trgstr,$srclen,$trglen,
			       $FeatTypes,$values);


    if (exists $$FeatTypes{lendiff}){
	$$values{lendiff}=abs($srclen-$trglen);
    }
    if (exists $$FeatTypes{lenratio}){
	if ($srclen>$trglen){
	    $$values{lenratio}=$trglen/$srclen;
	}
	else{
	    $$values{lenratio}=$srclen/$trglen;
	}
    }



    if (exists $$FeatTypes{isnumber}){
	if ($srcstr=~/^[\d\.\,]+\%?$/){
	    if ($trgstr=~/^[\d\.\,]+\%?$/){
		$$values{isnumber}=1;
	    }
	}
    }

    if (exists $$FeatTypes{hasdigit}){
	if ($self->{TREES}->is_terminal($src,$srcN)){
	    if ($self->{TREES}->is_terminal($trg,$trgN)){
		if ($srcstr=~/\d/){
		    if ($trgstr=~/\d/){
			$$values{digit}=1;
#			print STDERR "$srcstr .... $trgstr\n";
		    }
		}
	    }
	}
    }

    if (exists $$FeatTypes{ispunct}){
	if ($srcstr=~/^\p{P}$/){
	    if ($trgstr=~/^\p{P}$/){
		$$values{ispunct}=1;
	    }
	}
    }

    if (exists $$FeatTypes{punct}){
	if ($srcstr=~/^\p{P}$/){
	    if ($trgstr=~/^\p{P}$/){
		$$values{"punct\_$srcstr\_$trgstr"}=1;
	    }
	}
    }


    if (exists $$FeatTypes{haspunct}){
	if ($self->{TREES}->is_terminal($src,$srcN)){
	    if ($self->{TREES}->is_terminal($trg,$trgN)){
		if ($srcstr=~/\p{P}/){
		    if ($trgstr=~/\p{P}/){
			$$values{haspunct}=1;
#			print STDERR "$srcstr .... $trgstr\n";
		    }
		}
	    }
	}
    }

    if (exists $FeatTypes->{suffix}){
	if ($self->{TREES}->is_terminal($src,$srcN)){
	    if ($self->{TREES}->is_terminal($trg,$trgN)){
		if ($FeatTypes->{suffix}>0){
		    my $SuffixLength=$FeatTypes->{suffix};
		    my $suffixSrc = substr($srcstr, 0-$SuffixLength);
		    my $suffixTrg = substr($trgstr, 0-$SuffixLength);
		    my $pair = $suffixSrc.'_'.$suffixTrg;
		    $$values{'suffix_'.$pair} = 1;
		}
	    }
	}
    }

    if (exists $FeatTypes->{word}){
	if ($self->{TREES}->is_terminal($src,$srcN)){
	    if ($self->{TREES}->is_terminal($trg,$trgN)){
		my $pair = $srcstr.'_'.$trgstr;
		$$values{'word_'.$pair} = 1;
	    }
	}
    }

}



sub string_sim_features{
    my $self=shift;
    my ($srcstr,$trgstr,$srclen,$trglen,$FeatTypes,$values)=@_;

    if (exists $$FeatTypes{identical}){
	my $minLength=1;
	if (defined $$FeatTypes{identical}){
	    $minLength=$$FeatTypes{identical};
	}
	if ($srclen>=$minLength && $trglen>=$minLength){
	    if ($srcstr eq $trgstr){
		$$values{identical}=1;
	    }
	}
    }

    if (exists $$FeatTypes{lcsr}){
	my $minLength=1;
	if (defined $$FeatTypes{lcsr}){
	    $minLength=$$FeatTypes{lcsr};
	}
	if ($srclen>=$minLength && $trglen>=$minLength){
	    if ($srcstr eq $trgstr){
		$$values{lcsr}=1;
	    }
	    else{
		$$values{lcsr}=lcsr($srcstr,$trgstr);
	    }
	}
    }


    if (exists $$FeatTypes{lcsrlc}){
	my $minLength=1;
	if (defined $$FeatTypes{lcsrlc}){
	    $minLength=$$FeatTypes{lcsrlc};
	}
	if ($srclen>=$minLength && $trglen>=$minLength){
	    my $SrcStr=lc($srcstr);
	    my $TrgStr=lc($trgstr);
	    if ($SrcStr eq $TrgStr){
		$$values{lcsrlc}=1;
	    }
	    else{
		$$values{lcsrlc}=lcsr($SrcStr,$TrgStr);
	    }
	}
    }


    ## ignore non-ascii for lcsr scores!
    if (exists $$FeatTypes{lcsrascii}){
	my $SrcStr=$srcstr;
	my $TrgStr=$trgstr;
	$SrcStr=~s/[^a-z0-9]//gi;
	$TrgStr=~s/[^a-z0-9]//gi;
	my $minLength=0;
	if (defined $$FeatTypes{lcsrascii}){
	    $minLength=$$FeatTypes{lcsrascii};
	}
	if (length($SrcStr)>=$minLength && length($TrgStr)>=$minLength){
	    if ($SrcStr eq $TrgStr){
		$$values{lcsrascii} = 1;
	    }
	    else{
		$$values{lscrascii} = lcsr($SrcStr,$TrgStr);
	    }
	}
    }

    ## ignore non-ascii for lcsr scores!
    if (exists $$FeatTypes{lcsrcons}){
	my $SrcStr=$srcstr;
	my $TrgStr=$trgstr;
	$SrcStr=~s/[aeiuoAEIOUÀÁÂÃÄÅÆÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝàáâãäåæèéêëìíîïñòóôõöùúûüýÿ]//g;
	$TrgStr=~s/[aeiuoAEIOUÀÁÂÃÄÅÆÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝàáâãäåæèéêëìíîïñòóôõöùúûüýÿ]//g;

	my $minLength=0;
	if (defined $$FeatTypes{lcsrcons}){
	    $minLength=$$FeatTypes{lcsrcons};
	}
	if (length($SrcStr)>=$minLength && length($TrgStr)>=$minLength){
	    if ($SrcStr eq $TrgStr){
		$$values{lcsrcons} = 1;
	    }
	    else{
		$$values{lscrcons} = lcsr($SrcStr,$TrgStr);
	    }
	}
    }



}








sub lcsr{
    my ($str1,$str2)=@_;
    if (exists $__LCSR_CACHE{$str1}{$str2}){
	return $__LCSR_CACHE{$str1}{$str2};
    }
    my $score=&lcs($str1,$str2);
    if (length($str1)>length($str2)){
	$score/=length($str1);
    }
    if (length($str2)>0){
	$score/=length($str2);
    }
    if ($__LCSR_CACHE_COUNT<$__LCSR_CACHE_SIZE){
	$__LCSR_CACHE{$str1}{$str2}=$score;
	$__LCSR_CACHE_COUNT++;
    }
    return $score;
}



sub lcs {
  my ($src,$trg)=@_;
  my (@l,$i,$j);
  my @src_let=split(//,$src);
  my @trg_let=split(//,$trg);
  unshift (@src_let,'');
  unshift (@trg_let,'');
  for ($i=0;$i<=$#src_let;$i++){
      $l[$i][0]=0;
  }
  for ($i=0;$i<=$#trg_let;$i++){
      $l[0][$i]=0;
  }
  for $i (1..$#src_let){
      for $j (1..$#trg_let){
	  if ($src_let[$i] eq $trg_let[$j]){
	      $l[$i][$j]=$l[$i-1][$j-1]+1;
	  }
	  else{
	      if ($l[$i][$j-1]>$l[$i-1][$j]){
		  $l[$i][$j]=$l[$i][$j-1];
	      }
	      else{
		  $l[$i][$j]=$l[$i-1][$j];
	      }
	  }
      }
  }
  return $l[$#src_let][$#trg_let];
}




1;
__END__

=head1 NAME

=head1 SYNOPSIS

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
