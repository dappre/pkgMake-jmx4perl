#!/bin/sh

if [ -x /usr/lib/rpm/redhat/find-requires ] ; then
FINDREQ=/usr/lib/rpm/redhat/find-requires
else
FINDREQ=/usr/lib/rpm/find-requires
fi

$FINDREQ $* | sed -e '/perl(Crypt::OpenPGP)/d' | \
              sed -e '/perl(Crypt::OpenPGP::KeyRing)/d' | \
              sed -e '/perl(Term::ANSIColor)/d' | \
              sed -e '/perl(Term::Clui)/d' | \
              sed -e '/perl(Term::ShellUI)/d' | \
              sed -e '/perl(Easy)/d'

