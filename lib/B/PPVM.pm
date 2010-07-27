#!/usr/bin/perl -c

package B::PPVM;

use B;

use YAML::XS;


sub ppvm_dump {
    my ($memory, $what) = @_;

    my $bobj = eval { $what->isa('B::OBJECT') } ? $what : B::svref_2object($what);
    my $addr = ${$bobj};

    return if exists $memory->{$addr};

    $memory->{$addr} = 1;
    $memory->{$addr} = { $bobj->ppvm_dump($memory) };
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
        my ($bobj) = @_;
        return (
            class => B::class($bobj),
        );
    };
}

{
    package B::SV;
    sub ppvm_dump {
        my ($bobj) = @_;
        return (
            $bobj->SUPER::ppvm_dump,
            refcnt => $bobj->REFCNT,
            flags  => $bobj->FLAGS,
        );
    };
}

{
    package B::IV;
    sub ppvm_dump {
        my ($bobj) = @_;
        return (
            $bobj->SUPER::ppvm_dump,
            iv => $bobj->int_value,
        );
    };
}

{
    package B::PV;
    sub ppvm_dump {
        my ($bobj) = @_;
        return (
            $bobj->SUPER::ppvm_dump,
            pv => $bobj->PV,
        );
    };
}

{
    package B::PVIV;
    sub ppvm_dump {
        my ($bobj) = @_;
        return (
            $bobj->SUPER::ppvm_dump,
            iv => $bobj->int_value,
            pv => $bobj->PV,
        );
    };
}

{
    package B::PVMG;
    sub ppvm_dump {
        my ($bobj, $memory) = @_;

        B::PPVM::ppvm_dump($memory, $_) foreach $bobj->MAGIC;
        
        my $svstash = $bobj->SvSTASH->isa('B::HV') && $bobj->SvSTASH->NAME ne 'B::MAGIC'
            ? $bobj->SvSTASH
            : undef;
        B::PPVM::ppvm_dump($memory, $bobj->SvSTASH) if $svstash;

        return (
            $bobj->SUPER::ppvm_dump,
            magic   => [ map { ${$_} } $bobj->MAGIC ],
            svstash => $svstash ? ${$svstash} : 0,
        );
    };
}

{
    package B::MAGIC;
    sub ppvm_dump {
        my ($bobj) = @_;
        return (
            class => B::class($bobj),
            type  => $bobj->TYPE,
            ptr   => $bobj->PTR,
        );
    };
}

{
    package B::GV;
    sub ppvm_dump {
        my ($bobj, $memory) = @_;

        B::PPVM::ppvm_dump($memory, $bobj->SV);

        return (
            $bobj->SUPER::ppvm_dump,
            name => $bobj->NAME,
            sv   => ${$bobj->SV},
        );
    };
}

{
    package B::HV;
    sub ppvm_dump {
        my ($bobj, $memory) = @_;

        my @array;
        my %hash = $bobj->ARRAY;
        while (my ($key, $val) = each %hash) {
            B::PPVM::ppvm_dump($memory, $val);
            push @array, $key, ${$val};
        };

        return (
            $bobj->SUPER::ppvm_dump,
            name => $bobj->NAME,
            array => { @array },
        );
    };
}


1;
