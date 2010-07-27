#!/usr/bin/perl -c

package B::PPVM;

use B;

use YAML::XS;


sub ppvm_dump {
    my ($memory, $what) = @_;

    my $bobj = eval { $what->isa('B::OBJECT') } ? $what : B::svref_2object($what);
    my $addr = ${$bobj};

    return if exists $memory->{$addr};

    $memory->{$addr} = 1;  # prevent endless recursing
    return { $addr => ( $memory->{$addr} = { addr => $addr, $bobj->ppvm_dump($memory) } ) };
};


sub compile {
    my @args = @_;

    return sub {
        my $memory = +{};
        my $main_stash = \%main::;

        ppvm_dump($memory, $main_stash);
        print Dump $memory;

        return @args;
    };
};


{
    package B::OBJECT;
    sub ppvm_dump {
        my ($self) = shift;

        return (
            class => B::class($self),
        );
    };
}

{
    package B::MAGIC;
    sub ppvm_dump {
        my ($self) = shift;

        return (
            class => B::class($self),
            type  => $self->TYPE,
            ptr   => $self->PTR,
        );
    };
}

{
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
}

{
    package B::RV;
    sub ppvm_dump {
        my ($self) = shift;
        my ($memory) = my @args = @_;

        my $rv = $self->RV;
        B::PPVM::ppvm_dump($memory, $rv);

        return (
            $self->B::SV::ppvm_dump(@args),
            rv => ${$rv},
        );
    };
}

{
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
}

{
    package B::NV;
    sub ppvm_dump {
        my ($self) = shift;
        my ($memory) = my @args = @_;

        return (
            $self->SUPER::ppvm_dump(@args),
            nv => $self->NV,
        );
    };
}

{
    package B::PV;
    sub ppvm_dump {
        my ($self) = shift;
        my ($memory) = my @args = @_;

        return (
            $self->SUPER::ppvm_dump(@args),
            pv => $self->PV,
        );
    };
}

{
    package B::PVIV;
    sub ppvm_dump {
        my ($self) = shift;
        my ($memory) = my @args = @_;

	return ( $self->B::IV::ppvm_dump(@args), class => 'IV'  ) if $self->FLAGS & B::SVf_IOK;
	return ( $self->B::PV::ppvm_dump(@args), class => 'PV'  ) if $self->FLAGS & B::SVf_POK;
	return ();
    };
}

{
    package B::PVNV;
    sub ppvm_dump {
        my ($self) = shift;
        my ($memory) = my @args = @_;

	return ( $self->B::PVIV::ppvm_dump(@args) ) if $self->FLAGS & (B::SVf_IOK | B::SVf_POK);
	return ( $self->B::NV::ppvm_dump(@args), class => 'NV' ) if $self->FLAGS & B::SVf_NOK;
	return ();
    };
}

{
    package B::PVMG;
    sub ppvm_dump {
        my ($self) = shift;
        my ($memory) = my @args = @_;

        B::PPVM::ppvm_dump($memory, $_) foreach $self->MAGIC;

        my $svstash = $self->SvSTASH->isa('B::HV') && $self->SvSTASH->NAME ne 'B::MAGIC'
            ? $self->SvSTASH
            : undef;
        B::PPVM::ppvm_dump($memory, $self->SvSTASH) if $svstash;

        return (
            $self->B::OBJECT::ppvm_dump(@args),
            scalar $self->MAGIC ? ( magic   => [ map { ${$_} } $self->MAGIC ] ) : (),
            ${$svstash} ? ( svstash => ${$svstash} ) : 0,  # FIXME
        );
    };
}

{
    package B::GV;
    sub ppvm_dump {
        my ($self) = shift;
        my ($memory) = my @args = @_;

        B::PPVM::ppvm_dump($memory, $self->$_) foreach qw(SV AV HV);

        return (
            $self->SUPER::ppvm_dump(@args),
            name => $self->NAME,
            sv   => ${$self->SV},
            av   => ${$self->AV},
            hv   => ${$self->HV},
        );
    };
}

{
    package B::HV;
    sub ppvm_dump {
        my ($self) = shift;
        my ($memory) = my @args = @_;

        my @array;
        my %hash = $self->ARRAY;
        while (my ($key, $val) = each %hash) {
            B::PPVM::ppvm_dump($memory, $val);
            push @array, $key => ${$val};
        };

        return (
            $self->SUPER::ppvm_dump(@args),
            name => $self->NAME,
            array => { @array },
        );
    };
}


1;
