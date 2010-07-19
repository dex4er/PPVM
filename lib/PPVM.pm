package PPVM;

=head1 NAME

PPVM - Pure Perl Virtual Machine

=head1 SYNOPSIS

  $ ppvm -E 'say "Hello, world!"'
  Hello, world!

=head1 DESCRIPTION

This will be clean and pure reimplementation of Perl Virtual Machine (opcode
walker), coded in Pure Perl language, without usage of any XS modules and
dependency on B module.

The goal of PPVM is to provide a reference implementation which could be very
easy to port to other OO languages like Python or Java.  It will hopefuly
bring the Perl language to other Virtual Machines.

PPVM is not a full Perl interpreter and requires a Perl compiler which is
currently provided only by original Perl implementation.

The rules for PPVM:

* Designed in mind that the code might be ported to other language.

* Runtime interpreter separated from compiler.

* Modern OO without Perl-only idioms which can be hard to understanding.

=for readme stop

=cut

our $VERSION = '0.01';

use Mouse;


1;


=for readme continue

=head1 BUGS

The API is not stable yet and can be changed in future.

=head1 AUTHOR

Piotr Roszatycki <dexter@cpan.org>

=head1 LICENSE

Copyright (C) 2010 by Piotr Roszatycki <dexter@cpan.org>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
