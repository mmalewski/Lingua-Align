#
#
# KEEP_FEATURE_FILES
# KEEP_CLASSIFICATION_FILE
#

package Lingua::Align::Classifier::Megam;

use vars qw(@ISA $VERSION);
use strict;

use FileHandle;

$VERSION='0.1';
@ISA = qw( Lingua::Align::Classifier );



sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    $self->{MEGAM} = $attr{-megam} || 
	$ENV{HOME}.'/projects/align/MaxEnt/megam_i686.opt';
    $self->{MEGAM_ARGUMENTS} = $attr{-megam_arguments} || '';
    $self->{MEGAM_MODEL} = $attr{-megam_model_type} || 'binary';

    return $self;
}

sub initialize_classification{
    my $self=shift;

    $self->{TESTFILE} = $self->{-classification_data} || '__test.'.$$;
    $self->{TEST_FH} = new FileHandle;
    $self->{TEST_FH}->open(">$self->{TESTFILE}") || 
	die "cannot open data file $self->{TESTFILE}\n";
}

sub add_test_instance{
    my ($self,$feat)=@_;
    my $label = $_[2] || 0;
    if (not ref($self->{TEST_FH})){
	$self->initialize_classification();
    }
    my $fh=$self->{TEST_FH};
    print $fh $label.' ';
    print $fh join(' ',%{$feat});
    print $fh "\n";
}

sub initialize_training{
    my $self=shift;

    $self->{TRAINFILE} = $self->{-training_data} || '__train.'.$$;
    $self->{TRAIN_FH} = new FileHandle;
    $self->{TRAIN_FH}->open(">$self->{TRAINFILE}") || 
	die "cannot open training data file $self->{TRAINFILE}\n";
}


sub add_train_instance{
    my ($self,$label,$feat,$weight)=@_;
    if (not ref($self->{TRAIN_FH})){
	$self->initialize_training();
    }
    my $fh=$self->{TRAIN_FH};
    if (defined($weight) && ($weight != 1)){
	if ($weight>0){
	    print $fh $label.' $$$WEIGHT '.$weight.' ';
	}
    }
    else{
	print $fh $label.' ';
    }
    print $fh join(' ',%{$feat});
    print $fh "\n";
}

sub train{
    my $self = shift;
    my $model = shift || '__megam.'.$$;

#    $self->store_features_used($model);
    my $trainfile = $self->{TRAINFILE};

# .... train a new model

    my $arguments=$self->{MEGAM_ARGUMENTS}." -fvals ".$self->{MEGAM_MODEL};
    my $command = "$self->{MEGAM} $arguments $trainfile > $model";
    print STDERR "train with:\n$command\n" if ($self->{-verbose});
    system($command);

    unlink $trainfile unless $self->{-keep_training_data};
    return $model;
}

sub classify{
    my $self=shift;
    my $model = shift || '__megam.'.$$;

#    $self->store_features_used($model);
    my $testfile = $self->{TESTFILE};
    $self->{TEST_FH}->close();
    delete $self->{TEST_FH};

#    ## (better not ... just die ....)
#    if ($self->features_used($model) ne $self->features_used($testfile)){
#	die "\n\nnot the same features used for training and testing!\nre-run training!\n\n";
#    }

    my $arguments="-fvals -predict $model binary";
    my $command = "$self->{MEGAM} $arguments $testfile";
    print STDERR "classify with:\n$command\n" if ($self->{-verbose});
    my $results = `$command`;
    unlink $testfile;

    my @lines = split(/\n/,$results);

    my @scores=();
    foreach (@lines){
	my ($label,$score)=split(/\s+/);
	push (@scores,$score);
    }

    return @scores;

}





1;
