use inc::Module::Install;

name     'Modo';
all_from 'lib/Modo.pm';
author   q{Brad Haywood <brad@perlpowered.com>};
license  'perl';

build_requires 'Test::More';
requires 'autobox';

auto_install;

WriteAll;

