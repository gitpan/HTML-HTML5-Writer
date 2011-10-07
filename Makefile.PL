use strict;
use warnings;

use inc::Module::Install;

my $dist = 'HTML-HTML5-Writer';
my $fn   = "lib/$dist.pm"; $fn =~ s#-#/#g;

name                $dist;
perl_version_from   $fn;
version_from        $fn;
abstract_from       $fn;
readme_from         $fn;
author              'Toby Inkster <tobyink@cpan.org>';
license             'perl';

requires            'common::sense'         => 0;
requires            'Exporter'              => 0;
recommends          'HTML::HTML5::Sanity'   => 0;
requires            'HTML::HTML5::Entities' => '0.001';
recommends          'HTML::HTML5::Parser'   => 0;
test_requires       'Test::More'            => '0.61';
requires            'XML::LibXML'           => '1.60';

resources(
	'homepage'   => "https://metacpan.org/release/$dist",
	'repository' => "http://goddamn.co.uk/svn-web/perlmods/browse/$dist/",
	'bugtracker' => "http://rt.cpan.org/Dist/Display.html?Queue=$dist",
	);
	
write_doap_changes;
write_doap_changes_xml;
auto_license;
auto_manifest;

auto_install;
WriteAll(
	'meta' => 1,
	'sign' => 1,
	);
