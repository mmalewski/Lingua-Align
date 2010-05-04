package Lingua::Align::Features;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw();
$VERSION = '0.01';

use FileHandle;
use Lingua::Align::Corpus::Treebank;
use Lingua::Align::Corpus::Parallel::Giza;
use Lingua::Align::Corpus::Parallel::Moses;

# modules for feature extraction
use Lingua::Align::Features::Tree;
use Lingua::Align::Features::Lexical;
use Lingua::Align::Features::Alignment;
use Lingua::Align::Features::Orthography;
use Lingua::Align::Features::Cooccurrence;

my $DEFAULTFEATURES = 'inside2:outside2';

sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    foreach (keys %attr){$self->{$_}=$attr{$_};}

    # make a Treebank object for processing trees
    $self->{TREES} = new Lingua::Align::Corpus::Treebank();

    # make feature extraction objects for various feature types
    #   LEXICAL: lexical features such as inside/outside scores
    #      TREE: tree features such as span-similarity and label features
    # ALIGNMENT: alignment features such as gizae2f, moses, ...

    $self->{LEXICAL}      = new Lingua::Align::Features::Lexical(%attr);
    $self->{TREE}         = new Lingua::Align::Features::Tree(%attr);
    $self->{ALIGNMENT}    = new Lingua::Align::Features::Alignment(%attr);
    $self->{ORTHOGRAPHY}  = new Lingua::Align::Features::Orthography(%attr);
    $self->{COOCCURRENCE} = new Lingua::Align::Features::Cooccurrence(%attr);

    return $self;
}



sub initialize_features{
    my $self=shift;
    my $features=shift;

    # check if features is a pointer to a hash
    # or a string based feature specification

    if (ref($features) ne 'HASH'){
	if (not defined $features){
	    $features = $self->{-features} || $DEFAULTFEATURES;
	}
	my @feat=split(/\:/,$features);          # split feature string
	$self->{FEATURES}={};
	foreach (@feat){
	    my ($name,$val)=split(/\=/);
	    $self->{FEATURES}->{$name}=$val;
	}
    }
    %{$self->{FEATURE_TYPES}} = $self->feature_types();

    ## make a feature type string
    ## ... which we can use to look for specific requirements
    ##     (for example loading the moses lexicon)
    $self->{FEATURE_TYPES_STRING}=join(':',keys %{$self->{FEATURE_TYPES}});

    # initialize the other feature types
    if (exists $self->{TREE}){
	$self->{TREE}->initialize_features($features,@_);
    }
    if (exists $self->{ALIGNMENT}){
	$self->{ALIGNMENT}->initialize_features($features,@_);
    }
    if (exists $self->{LEXICAL}){
	$self->{LEXICAL}->initialize_features($features,@_);
    }
    if (exists $self->{ORTHOGRAPHY}){
	$self->{ORTHOGRAPHY}->initialize_features($features,@_);
    }
    if (exists $self->{COOCCURRENCE}){
	$self->{COOCCURRENCE}->initialize_features($features,@_);
    }

}



# return feature types used in all features used (simple or complex ones)

sub feature_types{
    my $self=shift;

    if (ref($self->{FEATURES}) ne 'HASH'){
	$self->initialize_features();
    }

    my %feattypes=();

    foreach my $f (keys %{$self->{FEATURES}}){
	if ($f=~/\*/){
	    my @fact = split(/\*/,$f);
	    foreach (@fact){
		$feattypes{$_}=$self->{FEATURES}->{$f};
	    }
	}

	## average
	elsif ($f=~/\+/){
	    my @fact = split(/\+/,$f);
	    foreach (@fact){
		$feattypes{$_}=$self->{FEATURES}->{$f};
	    }
	}

	# concatenations
	elsif ($f=~/\./){
	    my @fact = split(/\./,$f);
	    foreach (@fact){
		$feattypes{$_}=$self->{FEATURES}->{$f};
	    }
	}

	## standard single type features
	else{
	    $feattypes{$f}=$self->{FEATURES}->{$f};
	}
    }

    return %feattypes;

}


sub features{
    my $self=shift;
    my ($srctree,$trgtree,$srcnode,$trgnode)=@_;
    my %feat = $self->get_features($srctree,$trgtree,$srcnode,$trgnode);

    ## combine features if necessary
    my %retfeat=();
    foreach my $f (keys %{$self->{FEATURES}}){
	if ($f=~/\*/){                       # multiply factors
	    my @fact = split(/\*/,$f);
	    my $score=1;
	    foreach (@fact){
		if (exists $feat{$_}){
		    $score*=$feat{$_};
		}
		else{              # factor doesn't exist!
		    $score=0;      # --> score = 0 & stop!
		    last;
		}
	    }
	    $retfeat{$f}=$score;
	}

	elsif ($f=~/\+/){                    # average of factors
	    my @fact = split(/\+/,$f);
	    my $score=0;
	    foreach (@fact){
		if (exists $feat{$_}){
		    $score+=$feat{$_};
		}
	    }
	    $score/=($#fact+1);
	    $retfeat{$f}=$score;
	}

	elsif ($f=~/\./){                    # concatenate nominal features
	    my @fact = split(/\./,$f);
	    my $score=0;
	    my @keys=();
	    foreach my $x (@fact){           # for all factors
		my $found=0;
		foreach my $k (keys %feat){  # check if we have a feature
		    if ($k=~/^$x(\_|\Z)/){   # with this prefix
			push (@keys,$k);     # yes? --> concatenate
			$score+=$feat{$k};   # and add score
			$found=1;
			last;
		    }
		}
		if (not $found){             # nothing found?
		    push (@keys,$x);         # use prefix as key string
		}

	    }
	    if (@keys){
		my $key=join('_',@keys);   # this is the new feature string
		$score/=($#fact+1);        # this is the average score
		$retfeat{$key}=$score;     # (should be 1 for nominal)
	    }
	}

	else{                                # standard single type features
	    $retfeat{$f}=$feat{$f};
	}

	if ($retfeat{$f} == 0){
	    delete $retfeat{$f};
	}
    }


    foreach (keys %feat){
	if (not exists $retfeat{$_}){
	    if (/\_/){                   # feature template like 'pos'
		my @part = split(/\_/);
		if ($#part){
		    for my $x (0..$#part-1){
			my $key = join('_',@part[0..$x]);
			if (exists $self->{FEATURES}->{$key}){
			    $retfeat{$_}=$feat{$_};
			}
		    }
		}
	    }
	}
    }

#    print STDERR "$srcnode:$trgnode = ";
#    print STDERR join ":",%retfeat;
#    print STDERR "\n";

    return %retfeat;
}






sub clear_cache{
    my $self=shift;
    $self->{CACHE}={};   # is this good enough?
}



#-------------------------------------------------------------------
# get values for each feature type
#-------------------------------------------------------------------


sub get_features{
    my $self=shift;
    my ($src,$trg,$srcN,$trgN)=@_;
    my $features = $_[4] || $self->{FEATURE_TYPES};

    my %values=();

    ## check if we have the values stored in cache already
    ## (feature extraction is expensive and we do not want to repeat it
    ##  for the same nodes over and over again)

    my %todo=%{$features};
    my $key = "$src->{ID}:$trg->{ID}:$srcN:$trgN";
    foreach (keys %{$features}){
	if (exists $self->{CACHE}->{$key}->{$_}){
	    $values{$_}=$self->{CACHE}->{$key}->{$_};
	    delete $todo{$_};
	    $self->{CACHEACCESS}++;
	}
    }

    # get features of different types

    $self->{TREE}->get_features($src,$trg,$srcN,$trgN,\%todo,\%values);
    $self->{LEXICAL}->get_features($src,$trg,$srcN,$trgN,\%todo,\%values);
    $self->{ALIGNMENT}->get_features($src,$trg,$srcN,$trgN,\%todo,\%values);
    $self->{ORTHOGRAPHY}->get_features($src,$trg,$srcN,$trgN,\%todo,\%values);
    $self->{COOCCURRENCE}->get_features($src,$trg,$srcN,$trgN,\%todo,\%values);


    ## add features from immediate parents
    ## 1) both, source and target language parent

    my %parent_features=();
    foreach (keys %todo){
	if (/^parent_(.*)$/){
	    $parent_features{$1}=$features->{$_};
	}
    }
    if (keys %parent_features){
	my $srcparent=$self->{TREES}->parent($src,$srcN);
	my $trgparent=$self->{TREES}->parent($trg,$trgN);
	if ((defined $srcparent) && (defined $trgparent)){
	    my %newvalues = $self->get_features($src,$trg,
						$srcparent,$trgparent,
						\%parent_features);
	    foreach (keys %newvalues){
		$values{'parent_'.$_}=$newvalues{$_};
	    }
	}
    }

    ## 2) source language parent and current target language node

    my %parent_features=();
    foreach (keys %todo){
	if (/^srcparent_(.*)$/){
	    $parent_features{$1}=$features->{$_};
	}
    }
    if (keys %parent_features){
	my $srcparent=$self->{TREES}->parent($src,$srcN);
	if (defined $srcparent){
	    my %newvalues = $self->get_features($src,$trg,
						$srcparent,$trgN,
						\%parent_features);
	    foreach (keys %newvalues){
		$values{'srcparent_'.$_}=$newvalues{$_};
	    }
	}
    }


    ## 3) target language parent and current source language node

    my %parent_features=();
    foreach (keys %todo){
	if (/^trgparent_(.*)$/){
	    $parent_features{$1}=$features->{$_};
	}
    }
    if (keys %parent_features){
	my $trgparent=$self->{TREES}->parent($trg,$trgN);
	if (defined $trgparent){
	    my %newvalues = $self->get_features($src,$trg,
						$srcN,$trgparent,
						\%parent_features);
	    foreach (keys %newvalues){
		$values{'trgparent_'.$_}=$newvalues{$_};
	    }
	}
    }

    ## 4) sister nodes --> (max of) sister node features ...

    my %sister_features=();
    foreach (keys %todo){
	if (/^sister_(.*)$/){
	    $sister_features{$1}=$features->{$_};
	}
    }
    if (keys %sister_features){
	my @srcsisters=$self->{TREES}->sisters($src,$srcN);
	my @trgsisters=$self->{TREES}->sisters($trg,$trgN);

	## get features for all combinations of sister nodes ...
	foreach my $s (@srcsisters){
	    foreach my $t (@trgsisters){
		my %newvalues = $self->get_features($src,$trg,$s,$t,
						    \%sister_features);
		foreach (keys %newvalues){
		    ## only if not exists or value is bigger!
		    if ($newvalues{$_} > $values{'sister_'.$_}){
			$values{'sister_'.$_}=$newvalues{$_};
		    }
		}
	    }
	}
    }



    ## 5) children nodes --> children node features ...

    my %children_features=();
    foreach (keys %todo){
	if (/^children_(.*)$/){
	    $children_features{$1}=$features->{$_};
	}
    }
    if (keys %children_features){
	my @srcchildren=$self->{TREES}->children($src,$srcN);
	my @trgchildren=$self->{TREES}->children($trg,$trgN);

	## get features for all combinations of sister nodes ...
	foreach my $s (@srcchildren){
	    foreach my $t (@trgchildren){
		my %newvalues = $self->get_features($src,$trg,$s,$t,
						    \%children_features);
		foreach (keys %newvalues){
		    ## only if not exists or value is bigger!
		    if ($newvalues{$_} > $values{'children_'.$_}){
			$values{'children_'.$_}=$newvalues{$_};
		    }
		}
	    }
	}
    }


    ## save values in cache
    ## (could be useful if we need features from parents etc ....)

    foreach (keys %values){
	$self->{CACHE}->{$key}->{$_}=$values{$_};
	delete $values{$_} if (not $values{$_});
    }

    ## delete features with value = zero
    ## (but it's good to keep them in the cache
    ##  as we might have to look for them again)
    foreach (keys %values){
	delete $values{$_} if (not $values{$_});
    }

    return %values;	
}







sub feature{
    my $self=shift;
    my ($tree,$node)=@_;

    my @values=();
    foreach my $f (keys %{$self->{FEATURES}}){
	my $val = $self->get_feature($tree,$node,$f,$self->{FEATURES}->{$f});
	push(@values,$val) if ($val);
    }
    return join(':',@values);
}



# get features for a node in a tree

sub get_feature{
    my $self=shift;
    my ($tree,$node,$feature,$val)=@_;

    my $key = "$tree->{ID}:$node";
    if (exists $self->{CACHE}->{$key}->{$feature}){
	return $self->{CACHE}->{$key}->{$feature};
    }


    if ($feature=~/^parent_(.*)$/){
	my $newfeature = $1;
	my $parent=$self->{TREES}->parent($tree,$node);
	if (defined $parent){
	    return $self->get_feature($tree,$parent,$newfeature,$val);
	}
	return undef;
    }
    elsif ($feature=~/^children_(.*)$/){
	my $newfeature = $1;
	my @children=$self->{TREES}->children($tree,$node);
	my @feat=();
	foreach my $c (@children){
	    if (defined $c){
		push (@feat,$self->get_feature($tree,$c,$newfeature,$val))
	    }
	}
	return join(':',@feat);
    }
    elsif ($feature=~/^sister_(.*)$/){
	my $newfeature = $1;
	my @sisters=$self->{TREES}->sisters($tree,$node);
	my @feat=();
	foreach my $s (@sisters){
	    if (defined $s){
		push (@feat,$self->get_feature($tree,$s,$newfeature,$val))
	    }
	}
	return join(':',@feat);
    }



    elsif ($feature eq 'suffix'){
	if ($val>0){
	    if (exists $tree->{NODES}->{$node}->{word}){
		my $str = $tree->{NODES}->{$node}->{word};
		return substr($str, 0-$val);
	    }
	}
    }

    elsif ($feature eq 'prefix'){
	if ($val>0){
	    if (exists $tree->{NODES}->{$node}->{word}){
		my $str = $tree->{NODES}->{$node}->{word};
		return substr($str, $val);
	    }
	}
    }

    elsif ($feature eq 'edge'){
	if (exists $tree->{NODES}->{$node}->{RELATION}){
	    if (ref($tree->{NODES}->{$node}->{RELATION}) eq 'ARRAY'){
		return $tree->{NODES}->{$node}->{RELATION}->[0];
	    }
	}
    }

    
    elsif (exists $tree->{NODES}->{$node}->{$feature}){
	return $tree->{NODES}->{$node}->{$feature};
    }
    return undef;
}






1;
__END__

=head1 NAME

Lingua::Align::Trees::Features - Perl modules for feature extraction for the Lingua::Align::Trees tree aligner

=head1 SYNOPSIS

  use Lingua::Align::Trees::Features;

  my $FeatString = 'catpos:treespansim:parent_catpos';
  my $extractor = new Lingua::Align::Trees::Features(
                          -features => $FeatString);

  my %features = $extractor->features(\%srctree,\%trgtree,
                                      $srcnode,$trgnode);



  my $FeatString2 = 'giza:gizae2f:gizaf2e:moses';
  my $extractor2 = new Lingua::Align::Trees::Features(
                      -features => $FeatString2,
                      -lexe2f => 'moses/model/lex.0-0.e2f',
                      -lexf2e => 'moses/model/lex.0-0.f2e',
                      -moses_align => 'moses/model/aligned.intersect');

  my %features = $extractor2->features(\%srctree,\%trgtree,
                                       $srcnode,$trgnode);


=head1 DESCRIPTION

Extract features from a pair of nodes from two given syntactic trees (source and target language). The trees should be complex hash structures as produced by Lingua::Align::Corpus::Treebank::TigerXML. The returned features are given as simple key-value pairs (%features)

Features to be used are specified in the feature string given to the constructor ($FeatString). Default is 'inside2:outside2' which refers to 2 features, the inside score and the outside score as defined by the Dublin Sub-Tree Aligner (see http://www2.sfs.uni-tuebingen.de/ventzi/Home/Software/Software.html, http://ventsislavzhechev.eu/Downloads/Zhechev%20MT%20Marathon%202009.pdf). For this you will need the probabilistic lexicons as created by Moses (http://statmt.org/moses/); see the -lexe2f and -lexf2e parameters in the constructor of the second example.

Features in the feature string are separated by ':'. Feature types can be combined. Possible combinations are:

=over

=item product (*)

multiply the value of 2 or more feature types, e.g. 'inside2*outside2' would refer to the product of inside2 and outside2 scores

=item average (+)

compute the average (arithmetic mean) of 2 or more features,  e.g. 'inside2+outside2' would refer to the mean of inside2 and outside2 scores

=item concatenation (.)

merge 2 or more feature keys and compute the average of their scores. This can especially be useful for "nominal" feature types that have several instantiations. For example, 'catpos' refers to the labels of the nodes (category or POS label) and the value of this feature is either 1 (present). This means that for 2 given nodes the feature might be 'catpos_NN_NP => 1' if the label of the source tree node is 'NN' and the label of the target tree node is 'NP'. Such nominal features can be combined with real valued features such as inside2 scores, e.g. 'catpos.inside2' means to concatenate the keys of both feature types and to compute the arithmetic mean of both scores.

=back

We can also refer to parent nodes on source and/or target language side. A feature with the prefix 'parent_' makes the feature extractor to take the corresponding values from the first parent nodes in source and target language trees. The prefix 'srcparent_' takes the values from the source language parent (but the current target language node) and 'trgparent_' takes the target language parent but not the source language parent. For example 'parent_catpos' gets the labels of the parent nodes. These feature types can again be combined with others as described above (product, mean, concatenation). We can also use 'sister_' features 'children_' features which will refer to the feature with the maximum value among all sister/children nodes, respectively.


=head2 FEATURES

The following feature types are implemented in the Tree Aligner:



=head3 lexical equivalence features

Lexical equivalence features evaluate the relations between words dominated by the current subtree root nodes (alignment candidates). They all use lexical probabilities usually derived from automatic word alignment (other types of probabilistic lexica could be used as well). The notion of inside words refers to terminal nodes that are dominated by the current subtree root nodes and outside words refer to terminal nodes that are not dominated by the current subtree root nodes. Various variants of scores are possible:


=over

=item inside1 (insideST1*insideTS1)

This is the unnormalized score of words inside of the current subtrees (see http://ventsislavzhechev.eu/Downloads/Zhechev%20MT%20Marathon%202009.pdf). Lexical probabilities are taken from automatic word alignment (lex-files). NULL links  are also taken into account. It is actually the product of insideST1 (probabilities from source-to-target lexicon) and insideTS1 (probabilities from target-to-source lexicon) which also can be used separately (as individual features).

=item outside1 (outsideST1*outsideTS1)

The same as inside1 but for word pairs outside of the current subtrees. NULL links are counted and scores are not normalized.

=item inside2 (insideST2*insideTS2)

This refers to the normalized inside scores as defined in the Dublin Subtree Aligner.

=item outside2 (outsideST1*outsideTS1)

The normalized scores of word pairs outside of the subtrees.

=item inside3 (insideST3*insideTS3)

The same as inside1 (unnormalized) but without considering NULL links (which makes feature extraction much faster)

=item outside3 (outsideST1*outsideTS1)

The same as outside1 but without NULL links.

=item inside4 (insideST4*insideTS4)

The same as inside2 but without NULL links.

=item outside4 (insideST4*insideTS4)

The same as outside2 but without NULL links.



=item maxinside (maxinsideST*maxinsideTS)

This is basically the same as inside4 but using "max P(x|y)" instead of "1/|y \SUM P(x|y)" as in the original definition. maxinsideST is using the source-to-target scores and maxinsideTS is using the target-to-source scores.

=item maxoutside (maxoutsideST*maxoutsideTS)

The same as maxinside but for outside word pairs

=item avgmaxinside (avgmaxinsideST*avgmaxinsideTS)

This is the same as maxinside but computing the average (1/|x|\SUM_x max P(x|y)) instead of the product (\PROD_x max P(x|y))

=item avgmaxoutside (avgmaxoutsideST*avgmaxoutsideTS)

The same as avgmaxinside but for outside word pairs

=item unioninside (unioninsideST*unioninsideTS)

Add all lexical probabilities using the addition rule of independent but not mutually exclusive probabilities (P(x1|y1)+P(x2|y2)-P(x1|y1)*P(x2|y2))

=item unionoutside (unionoutsideST*unionoutsideTS)

The same as unioninside but for outside word pairs.

=back







=head3 word alignment features

Word alignment features use the automatic word alignment directly. Again we distinguish between words that are dominated by the current subtree root nodes (inside) and the ones that are outside. Alignment is binary (1 if two words are aligned and 0 if not) and as a score we usuallty compute the proportion of interlinked inside word pairs among all links involving either source or target inside words. One exception is the moselink feature which is only defined for terminal nodes.

=over

=item moses

The proportion of interlinked words (from automatic word alignment) inside of the current subtree among all links involving either source or target words inside of the subtrees.

=item moseslink

Only for terminal nodes: is set to 1 if the twwo words are linked in the automatic word alignment derived from GIZA++/Moses.

=item gizae2f

Link proportion as for moses but now using the assymmetric GIZA++ alignments only (source-to-target).

=item gizaf2e

Link proportion as for moses but now using the assymmetric GIZA++ alignments only (target-to-source).

=item giza

Links from gizae2f and gizaf2e combined.

=back




=head3 sub-tree features

Sub-tree features refer to features that are related to the structure and position of the current subtrees.

=over 

=item treespansim

This is a feature for measuring the "horizontal" similarity of the subtrees under consideration. It is defined as the 1 - the relative position difference of the subtree spans. The relative position of a subtree is defined as the middle of the span of a subtree (begin+end/2) divided by the length of the sentence.

=item treelevelsim

This is a feature measuring the "vertical" similarity of two nodes. It is defined as 1 - the relative tree level difference. The relative tree level is defined as the distance to the sentence root node divided by the size of the tree (which is the maximum distance of any node in the tree to the sentence root).

=item nrleafsratio

This is the ratio of the number of leaf nodes dominated by the two candidate nodes. The ratio is defined as the minimum(nr_src_leafs/nr_trg_leafs,nr_trg_leafs/nr_src_leafs).

=back




=head3 annotation/label features

=over

=item C<catpos>

This feature type extracts node label pairs and gives them the value 1. It uses the "cat" attribute if it exists, otherwise it uses the "pos" attribute if that one exists.

=item C<edge>

This feature refers to the pairs of edge labels (relations) of the current nodes to their immediate parent (only the first parent is considered if multiple exist). This is a binary feature and is set to 1 for each observed label pair.

=back


=head3 co-occurrence features

Measures of co-occurrence can also be used as features. Currently Dice scores are supported that will be computed "on-the-fly" from co-occurrence frequency counts. Frequencies should be stored in plain text files using a simple format:

Source/target language frequencies: First line starts with '#' and specifies the node features used (for example '# word' means that the actual surface words will be used). All other lines should contain three items, the actual token, a unique token ID and the frequency (all separated by one TAB character). A file should look like this:

  # word
  learned 682     4
  stamp   722     3
  hat     1056    5
  what    399     20
  again   220     14

Co-occurrence frequencies are also stored in plain text files with the following format: The first two lines specify the files which are used to store source and target language frequencies. All other lines contain source token ID, target token ID and the corresponding co-occurrence frequency. An example could look like this:

  # source frequencies: word.src
  # target frequencies: word.trg
  127     32      4
  127     898     3
  127     31      3
  798     64      3
  798     861     4

The easiest way to produce such frequency files is to use the script C<coocfreq> in the C<bin> directory of Lingua-Align. Look at the header of this script for possible options. 

Features for the frequency counts can be quite complex. Any node attribute can be used. Special features are C<suffix=X>, C<prefix=X> which refer to word-suffix resp. word-prefix of length X (number of characters). Another special feature is C<edge> which refers to the relation to the head of the current node. Features can also be combined (separate each feature with one ':' character). You may also use features of context nodes using 'parent_', 'children_' and 'sister_' as for the alignment features. Here is an example of a complex feature:

  word:pos:parent_suffix=3:parent_cat

This refers to the surface word at the current node, its POS label, the 3-letter-suffix and the category label of the parent node. All these feature values will be concatenated with ':' and frequencies refer to those concatenated strings.

=over

=item C<diceNAME=COOCFILE>

Using features that start with the prefix 'dice' you can use Dice scores as features which will be computed from the frequencies in COOCFILE (and the source/target frequencies in the files specified in COOCFILE). You have to give each dice-feature a unique name (NAME) if you want to use several Dice score features. For example C<dicePOS=pos.coocfreq> enables Dice score features over POS-label co-occurrence frequencies stored in pos.coocfreq (if that's what you've stored in pos.coocfreq).

You may again use context features in the same way as for all other features, for example, 'sister_dicePOS=pos.coocfreq'. Note that co-occurrence features not always exist for all nodes in the tree (for example POS labels do not exist for non-terminal nodes).


=back


=head3 "orthographic" features

You can also use features that are based on the comparison and combination of strings. There are (sub)string features, string similarity features, string class features and length comparison features.

=over

=item C<lendiff>

This is the absolute character length difference of the source and the target language strings dominated by the current nodes.

=item C<lenratio>

This is the character-length ratio of the source and the target language strings dominated by the current nodes (shorter string divided by longer string)

=item C<word>

This is the pair of words at the current node (leaf nodes only).

=item C<suffix=X>

This is the pair of suffixes of length X from both source and target language words (leaf nodes only).

=item C<prefix=X>

This is the pair of prefixes of length X from both source and target language words (leaf nodes only).

=item C<isnumber>

This feature is set to 1 if both strings match the pattern /^[\d\.\,]+\%?$/

=item C<hasdigit>

This feature is set to 1 if both strings contain at least one digit.

=item C<haspunct>

This feature is set to 1 if both strings contain punctuations.

=item C<ispunct>

This feature is set to 1 if both strings are single character punctuations.

=item C<punct>

This feature is set to the actual pair of strings if both strings are single character punctuations.

=item C<identical=minlength>

This feature is 1 if both strings are longer than C<minlength> and are identical.

=item C<lcsr=minlength>

This feature is the longest subsequence ratio between the two strings if they are both longer than C<minlength> characters.

=item C<lcsrlc=minlength>

This is the same as C<lcsr> but using lowercased strings.

=item C<lcsrascii=minlength>

This is the same as C<lcsr> but using only the ASCII characters in both strings.

=item C<lcsrcons=minlength>

This is the same as C<lcsr> but uses a simple regex to remove all vowels (using a fixed set of characters to match).







=back






=head1 SEE ALSO

For the tree structure see L<Lingua::Align::Corpus::Treebank>.
For the tree aligner look at L<Lingua::Align::Trees>


=head1 AUTHOR

Joerg Tiedemann, E<lt>j.tiedemann@rug.nlE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
