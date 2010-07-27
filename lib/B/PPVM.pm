#!/usr/bin/perl -c

package B::PPVM;


sub compile {
    my @args = @_;

    my @newargs;
    my $dumper_class = 'B::PPVM::Dumper::YAML';

    foreach my $arg (@args) {
        if ($arg eq '-perl') {
            $dumper_class = 'B::PPVM::Dumper::Perl';
        }
        elsif ($arg eq '-yaml') {
            $dumper_class = 'B::PPVM::Dumper::YAML';
        }
        elsif ($arg eq '-json') {
            $dumper_class = 'B::PPVM::Dumper::JSON';
        }
        else {
            push @newargs, $arg;
        }
    };

    return sub {
        my $memory = B::PPVM::Memory->new;
        my $dumper = $dumper_class->new;

        my $main_stash = \%main::;

        $memory->add_object($main_stash);
        $dumper->dump( +{ %{$memory} } );

        return @newargs;
    };
};


package B::PPVM::Dumper::YAML;

use YAML::Tiny;

sub new {
    my ($class) = @_;
    return bless +{} => $class;
};

sub dump {
    my ($self, $what) = @_;
    print Dump $what;
};


package B::PPVM::Dumper::JSON;

use JSON;

sub new {
    my ($class) = @_;
    return bless +{} => $class;
};

sub dump {
    my ($self, $what) = @_;
    print encode_json $what;
};


package B::PPVM::Dumper::Perl;

use Data::Dumper;

sub new {
    my ($class) = @_;
    return bless +{} => $class;
};

sub dump {
    my ($self, $what) = @_;
    print Dumper $what;
};


package B::PPVM::Memory;

use B;

sub new {
    my ($class) = @_;

    return bless +{} => $class;
};

sub add_object {
    my ($self, $what) = @_;

    my $bobj = eval { $what->isa('B::OBJECT') } ? $what : B::svref_2object($what);
    my $addr = ${$bobj};

    return if exists $self->{$addr};

    $self->{$addr} = 1;  # prevent endless recursing
    $self->{$addr} = {
        addr => $addr,
        $bobj->ppvm_dump($self),
    };

    return { $addr => $self->{addr} };
};


package B::OBJECT;

sub ppvm_dump {
    my ($self) = shift;

    return (
        class => B::class($self),
    );
};


package B::MAGIC;

sub ppvm_dump {
    my ($self) = shift;

    return (
        class => B::class($self),
        type  => $self->TYPE,
        ptr   => $self->PTR,
    );
};


package B::SV;

sub ppvm_dump {
    my ($self) = shift;
    my ($memory) = my @args = @_;

    return (
        $self->SUPER::ppvm_dump(@args),
        refcnt => $self->REFCNT,
        flags  => $self->FLAGS,
    );
};


package B::RV;

sub ppvm_dump {
    my ($self) = shift;
    my ($memory) = my @args = @_;

    my $rv = $self->RV;
    $memory->add_object($rv);

    return (
        $self->B::SV::ppvm_dump(@args),
        rv => ${$rv},
    );
};


package B::IV;

sub ppvm_dump {
    my ($self) = shift;
    my ($memory) = my @args = @_;

    return ( $self->B::RV::ppvm_dump(@args), class => 'RV' ) if $self->FLAGS & B::SVf_ROK;

    return (
        $self->SUPER::ppvm_dump(@args),
        iv => $self->int_value,
    );
};


package B::NV;

sub ppvm_dump {
    my ($self) = shift;
    my ($memory) = my @args = @_;

    return (
        $self->SUPER::ppvm_dump(@args),
        nv => $self->NV,
    );
};


package B::PV;

sub ppvm_dump {
    my ($self) = shift;
    my ($memory) = my @args = @_;

    return (
        $self->SUPER::ppvm_dump(@args),
        pv => $self->PV,
    );
};


package B::PVIV;

sub ppvm_dump {
    my ($self) = shift;
    my ($memory) = my @args = @_;

    return ( $self->B::IV::ppvm_dump(@args), class => 'IV'  ) if $self->FLAGS & B::SVf_IOK;
    return ( $self->B::PV::ppvm_dump(@args), class => 'PV'  ) if $self->FLAGS & B::SVf_POK;
    return ();
};


package B::PVNV;

sub ppvm_dump {
    my ($self) = shift;
    my ($memory) = my @args = @_;

    return ( $self->B::PVIV::ppvm_dump(@args) ) if $self->FLAGS & (B::SVf_IOK | B::SVf_POK);
    return ( $self->B::NV::ppvm_dump(@args), class => 'NV' ) if $self->FLAGS & B::SVf_NOK;
    return ();
};


package B::PVMG;

sub ppvm_dump {
    my ($self) = shift;
    my ($memory) = my @args = @_;

    $memory->add_object($_) foreach $self->MAGIC;

    my $svstash = $self->SvSTASH->isa('B::HV') && $self->SvSTASH->NAME ne 'B::MAGIC'
        ? $self->SvSTASH
        : undef;
    $memory->add_object($self->SvSTASH) if $svstash;

    return (
        $self->B::OBJECT::ppvm_dump(@args),

#        scalar $self->MAGIC ? ( magic => [ map { ${$_} } $self->MAGIC ] ) : (),
#        ${$svstash} ? ( svstash => ${$svstash} ) : 0,  # FIXME
    );
};


package B::GV;

sub ppvm_dump {
    my ($self) = shift;
    my ($memory) = my @args = @_;

    $memory->add_object($self->$_) foreach qw(SV AV HV);

    return (
        $self->SUPER::ppvm_dump(@args),
        name => $self->NAME,
        ${$self->SV} ? (sv => ${$self->SV} ) : (),
        ${$self->AV} ? (av => ${$self->AV} ) : (),
        ${$self->HV} ? (hv => ${$self->HV} ) : (),
        ${$self->CV} ? (cv => ${$self->CV} ) : (),
    );
};


package B::AV;

sub ppvm_dump {
    my ($self) = shift;
    my ($memory) = my @args = @_;

    $memory->add_object($_) foreach $self->ARRAY;

    return (
        $self->SUPER::ppvm_dump(@args),
        array => [ map { ${$_} } $self->ARRAY ],
    );
};


package B::HV;

sub ppvm_dump {
    my ($self) = shift;
    my ($memory) = my @args = @_;

    my @array;
    my %hash = $self->ARRAY;
    while (my ($key, $val) = each %hash) {
        $memory->add_object($val);
        push @array, $key => ${$val};
    };

    return (
        $self->SUPER::ppvm_dump(@args),
        name => $self->NAME,
        array => { @array },
    );
};


1;


# TODO: exclude this package
