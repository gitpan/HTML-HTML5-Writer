use utf8;

use Test::More tests => 3;
BEGIN { use_ok('HTML::HTML5::Writer') };
use HTML::HTML5::Parser;

my $input = <<INPUT;
<title>foo</title>
<style type="text/css">
p { foo: "€"; }
</style>
<br foo=nar>
<!-- ffooo-->
<p bum=/bat/ quux=xyzzy hidden bim="&quot;">foo & €</p><p>foo</p>
<table>
<thead>
<tr><th><th>
</thead>
<tr><th><td>
<tbody><tr><th><td>
</table>
INPUT

my $parser = HTML::HTML5::Parser->new;
my $dom    = $parser->parse_string($input);

my $hwriter = HTML::HTML5::Writer->new(markup=>'html');
my $xwriter = HTML::HTML5::Writer->new(markup=>'xhtml',doctype=>HTML::HTML5::Writer::DOCTYPE_XHTML1);

is($hwriter->document($dom), <<HTML, 'HTML output');
<!DOCTYPE html><title>foo</title>
<style type="text/css">
p { foo: "€"; }
</style>
<br foo=nar>
<!-- ffooo-->
<p bim='"' quux=xyzzy hidden bum="/bat/">foo &amp; €<p>foo</p>
<table>
<thead>
<tr><th><th>
</thead>
<tbody><tr><th><td>
<tr><th><td>
</table>
HTML

is($xwriter->document($dom)."\n", <<XHTML, 'XHTML output');
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"><html xmlns="http://www.w3.org/1999/xhtml"><head><title>foo</title>
<style type="text/css">
p { foo: "€"; }
</style>
</head><body><br foo="nar" />
<!-- ffooo-->
<p bim='"' quux="xyzzy" hidden="" bum="/bat/">foo &#26; €</p><p>foo</p>
<table>
<thead>
<tr><th></th><th>
</th></tr></thead>
<tbody><tr><th></th><td>
</td></tr></tbody><tbody><tr><th></th><td>
</td></tr></tbody></table>
</body></html>
XHTML

