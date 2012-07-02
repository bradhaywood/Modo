#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Modo' ) || print "Bail out!\n";
}

diag( "Testing Modo $Modo::VERSION, Perl $], $^X" );
