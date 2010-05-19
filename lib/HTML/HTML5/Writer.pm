package HTML::HTML5::Writer;

use 5.008;
use base qw'Exporter';
use common::sense;
use XML::LibXML qw':all';

use constant {
	DOCTYPE_NIL         => '' ,
	DOCTYPE_HTML32      => '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">' ,
	DOCTYPE_HTML4       => '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">' ,
	DOCTYPE_HTML5       => '<!DOCTYPE html>' ,
	DOCTYPE_LEGACY      => '<!DOCTYPE html SYSTEM "about:legacy-compat">' ,
	DOCTYPE_XHTML1      => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">' ,
	DOCTYPE_XHTML11     => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">' ,
	DOCTYPE_XHTML_BASIC => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML Basic 1.1//EN" "http://www.w3.org/TR/xhtml-basic/xhtml-basic11.dtd">' ,
	DOCTYPE_XHTML_RDFA  => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML+RDFa 1.0//EN" "http://www.w3.org/MarkUp/DTD/xhtml-rdfa-1.dtd">' ,
	};

our $VERSION = '0.03';

our %EXPORT_TAGS = (
	'doctype' => [qw(DOCTYPE_NIL DOCTYPE_HTML32 DOCTYPE_HTML4
		DOCTYPE_HTML5 DOCTYPE_LEGACY DOCTYPE_XHTML1 DOCTYPE_XHTML11
		DOCTYPE_XHTML_BASIC DOCTYPE_XHTML_RDFA)]
	);
our @EXPORT_OK = @{ $EXPORT_TAGS{'doctype'} };

our %Entities;
our @VoidElements = qw(area base br col command embed hr img input keygen
	link meta param source wbr);
our @BooleanAttributes = qw(hidden autofocus disabled checked selected
	formnovalidate multiple readonly required details@open dl@compact
	audio@autoplay audio@preload audio@controls audio@loop
	form@novalidate hr@noshade iframe@seamless img@ismap ol@reversed
	script@async script@defer style@scoped time@pubdate
	video@autoplay video@preload video@controls video@loop);
our @OptionalStart = qw(html head body tbody);
our @OptionalEnd = qw(html head body tbody dt dd li optgroup option p
	rp rt td th tfoot thead tr);

BEGIN
{
	eval 'use HTML::HTML5::Parser::NamedEntityList;';
	unless (@!)
	{
		while (my ($entity, $char) = each(%{ $HTML::HTML5::Parser::TagSoupParser::EntityChar }))
		{
			$Entities{$char} = $entity
				if $entity =~ /;$/ 
				&& $Entities{$char} cmp $entity;
		}
	}
	
	$Entities{'&'}  = 'amp;';
	$Entities{'"'}  = 'quot;';
	$Entities{'<'}  = 'lt;';
	$Entities{'>'}  = 'gt;';
}

sub new
{
	my ($class, %opts) = @_;
	$opts{'markup'}   ||= 'html';
	$opts{'doctype'}  ||= DOCTYPE_HTML5;
	$opts{'charset'}  ||= 'utf8';
	return bless \%opts, $class;
}

sub is_xhtml
{
	my ($self) = @_;
	return ($self->{'markup'} =~ m'^(xml|xhtml|application/xml|text/xml|application/xhtml\+xml)$'i);
}

sub is_polyglot
{
	my ($self) = @_;
	return ($self->{'polyglot'} =~ /(yes|1)/i);
}

sub should_quote_attributes
{
	my ($self) = @_;
	return ($self->{'quote_attributes'} =~ /(yes|1|always|force)/i)
		|| $self->is_xhtml
		|| $self->is_polyglot;
}

sub should_slash_voids
{
	my ($self) = @_;
	return ($self->{'voids'} =~ /(slash)/i)
		|| $self->is_xhtml
		|| $self->is_polyglot;
}

sub should_force_end_tags
{
	my ($self) = @_;
	return ($self->{'end_tags'} =~ /(yes|1|always|force)/i)
		|| $self->is_xhtml
		|| $self->is_polyglot;
}

sub should_force_start_tags
{
	my ($self) = @_;
	return ($self->{'start_tags'} =~ /(yes|1|always|force)/i)
		|| $self->is_xhtml
		|| $self->is_polyglot;
}

sub document
{
	my ($self, $document) = @_;
	return $self->doctype() . $self->element($document->documentElement);
}

sub doctype
{
	my ($self) = @_;
	return $self->{'doctype'};
}

sub element
{
	my ($self, $element) = @_;
	
	return $element->toString
		unless $element->namespaceURI eq 'http://www.w3.org/1999/xhtml';
	
	my $rv = '';
	my $tagname  = $element->nodeName;
	my @attrs    = $element->attributes;
	my @kids     = $element->childNodes;

	if ($tagname eq 'html' && !$self->is_xhtml && !$self->is_polyglot)
	{
		@attrs = grep { $_->nodeName ne 'xmlns' } @attrs;
	}

	my $omitstart = 0;
	if (!@attrs and !$self->should_force_start_tags and grep { $tagname eq $_ } @OptionalStart)
	{
		$omitstart += eval "return \$self->_check_omit_start_${tagname}(\$element);";
	}

	my $omitend = 0;
	if (!$self->should_force_end_tags and grep { $tagname eq $_ } @OptionalEnd)
	{
		$omitend += eval "return \$self->_check_omit_end_${tagname}(\$element);";
	}

	unless ($omitstart)
	{
		$rv .= '<'.$tagname;
		foreach my $a (@attrs)
		{
			$rv .= ' '.$self->attribute($a, $element);
		}
	}
	
	if (!@kids and grep { $tagname eq $_ } @VoidElements and !$omitstart)
	{
		$rv .= $self->should_slash_voids ? ' />' : '>';
		return $rv;
	}
	
	$rv .= '>' unless $omitstart;
	
	foreach my $kid (@kids)
	{
		if ($kid->nodeName eq '#text')
			{ $rv .= $self->text($kid); }
		elsif ($kid->nodeName eq '#comment')
			{ $rv .= $self->comment($kid); }
		elsif ($kid->nodeName eq '#cdata-section')
			{ $rv .= $self->cdata($kid); }
		else
			{ $rv .= $self->element($kid); }			
	}
	
	unless ($omitend)
	{
		$rv .= '</'.$tagname.'>';
	}
	
	return $rv;
}

sub attribute
{
	my ($self, $attr, $element) = @_;
	
	my $minimize  = 0;
	my $quote     = 1;
	my $quotechar = '"';
	
	my $attrname = $attr->nodeName;
	my $elemname = $element ? $element->nodeName : '*';
	
	unless ($self->should_quote_attributes)
	{
		if (($attr->value eq $attrname or $attr->value eq '')
		and grep { $_ eq $attrname or $_ eq sprintf('%s@%s',$elemname,$attrname) } @BooleanAttributes)
		{
			return $attrname;
		}
		
		if ($attr->value =~ /^[A-Za-z0-9\._:-]+$/)
		{
			return sprintf('%s=%s', $attrname, $attr->value);
		}
	}
	
	my $encoded_value;
	if ($attr->value !~ /\"/)
	{
		$quotechar     = '"';
		$encoded_value = $self->encode_entities($attr->value);
	}
	elsif ($attr->value !~ /\'/)
	{
		$quotechar     = "'";
		$encoded_value = $self->encode_entities($attr->value);
	}
	else
	{
		$quotechar     = '"';
		$encoded_value = $self->encode_entities($attr->value,
			characters => "\"");
	}
	
	return sprintf('%s=%s%s%s', $attrname, $quotechar, $encoded_value, $quotechar);
}

sub comment
{
	my ($self, $text) = @_;
	return '<!--' . $self->encode_entities($text->nodeValue) . '-->';
}

sub cdata
{
	my ($self, $text) = @_;
	if (!$self->is_xhtml && $text->parentNode->nodeName =~ /^(script|style)$/i)
	{
		return $text->nodeValue;
	}
	elsif(!$self->is_xhtml)
	{
		return $self->text($text);
	}
	else
	{
		return '<![CDATA[' . $text->nodeValue . ']]>';
	}
}
	
sub text
{
	my ($self, $text) = @_;
	if (!$self->is_xhtml && $text->parentNode->nodeName =~ /^(script|style)$/i)
	{
		return $text->nodeValue;
	}
	elsif ($text->parentNode->nodeName =~ /^(script|style)$/i)
	{
		return '<![CDATA[' . $text->nodeValue . ']]>';
	}
	return $self->encode_entities($text->nodeValue,
		characters => "<>");
}
	
sub encode_entities
{
	my ($self, $string, %options) = @_;
	
	my $characters = $options{'characters'};
	$characters   .= '&';
	$characters   .= '\x{0}-\x{8}\x{B}\x{C}\x{E}-\x{1F}\x{26}\x{7F}';
	$characters   .= '\x{80}-\x{FFFFFF}' unless $self->{'charset'} =~ /^utf[_-]?8$/i;

	$string =~ s/ ([$characters]) / $self->encode_entity($1) /egx;
	
	return $string;
}

sub encode_entity
{
	my ($self, $char) = @_;
	return unless defined $char;

	if ($char =~ /&<>"/)
	{
		return '&' . $Entities{$char};
	}
	elsif (!$self->is_xhtml && defined $Entities{$char})
	{
		return '&' . $Entities{$char};
	}
	elsif ($self->{'refs'} =~ /dec/i)
	{
		return sprintf('&#%d;', ord $char);
	}

	return sprintf('&#%x;', ord $char);
}

sub _check_omit_end_body
{
	my ($self, $element) = @_;
	my $next = $element->nextSibling;
	unless (defined $next && $next->nodeName eq '#comment')
	{
		return 1 if $element->childNodes || !$self->_check_omit_start_body($element);
	}
}

sub _check_omit_end_head
{
	my ($self, $element) = @_;
	my $next = $element->nextSibling;
	return 0 unless defined $next;
	return 0 if $next->nodeName eq '#comment';
	return 0 if $next->nodeName eq '#text' && $next->nodeValue =~ /^\s/;
	return 1;
}

sub _check_omit_end_html
{
	my ($self, $element) = @_;
	
	my @bodies = $element->getChildrenByTagName('body');
	if ($bodies[-1]->childNodes || $bodies[-1]->attributes)
	{
		return !defined $element->nextSibling;
	}
}

sub _check_omit_end_dd
{
	my ($self, $element) = @_;
	
	return 1 unless defined $element->nextSibling;
	return 1 if $element->nextSibling->nodeName
		=~ /^( dd | dt )$/x;
}

*_check_omit_end_dt = \&_check_omit_end_dd;

sub _check_omit_end_li
{
	my ($self, $element) = @_;
	
	return 1 unless defined $element->nextSibling;
	return 1 if $element->nextSibling->nodeName
		=~ /^( li )$/x;
}

sub _check_omit_end_optgroup
{
	my ($self, $element) = @_;
	
	return 1 unless defined $element->nextSibling;
	return 1 if $element->nextSibling->nodeName
		=~ /^( optgroup )$/x;
}

sub _check_omit_end_option
{
	my ($self, $element) = @_;
	
	return 1 unless defined $element->nextSibling;
	return 1 if $element->nextSibling->nodeName
		=~ /^( option | optgroup )$/x;
}

sub _check_omit_end_p
{
	my ($self, $element) = @_;
	
	return 1 unless defined $element->nextSibling;
	return 1 if $element->nextSibling->nodeName
		=~ /^( address | article | aside | blockquote | dir
			| div | dl | fieldset | footer | form | h[1-6]
			| header | hr | menu | nav | ol | p | pre | section
			| table | ul )$/x;
}

sub _check_omit_end_rp
{
	my ($self, $element) = @_;
	
	return 1 unless defined $element->nextSibling;
	return 1 if $element->nextSibling->nodeName
		=~ /^( rp | rt )$/x;
}

*_check_omit_end_rt = \&_check_omit_end_rp;

sub _check_omit_end_td
{
	my ($self, $element) = @_;
	
	return 1 unless defined $element->nextSibling;
	return 1 if $element->nextSibling->nodeName
		=~ /^( td | th )$/x;
}

*_check_omit_end_th = \&_check_omit_end_td;

sub _check_omit_end_tbody
{
	my ($self, $element) = @_;
	
	return 1 unless defined $element->nextSibling;
	return 1 if $element->nextSibling->nodeName
		=~ /^( tbody | tfoot )$/x;
}

sub _check_omit_end_tfoot
{
	my ($self, $element) = @_;
	
	return 1 unless defined $element->nextSibling;
	return 1 if $element->nextSibling->nodeName
		=~ /^( tbody )$/x;
}

sub _check_omit_end_thead
{
	my ($self, $element) = @_;
	
	return 0 unless defined $element->nextSibling;
	return 1 if $element->nextSibling->nodeName
		=~ /^( tbody | tfoot )$/x;
}

sub _check_omit_end_tr
{
	my ($self, $element) = @_;
	
	return 1 unless defined $element->nextSibling;
	return 1 if $element->nextSibling->nodeName
		=~ /^( tr )$/x;
}

sub _check_omit_start_body
{
	my ($self, $element) = @_;
	my @kids = $element->childNodes;
	my $next = $kids[0];
	return 0 unless defined $next;
	return 0 if $next->nodeName eq '#comment';
	return 0 if $next->nodeName eq '#text' && $next->nodeValue =~ /^\s/;
	return 0 if $next->nodeName eq 'style';
	return 0 if $next->nodeName eq 'script';
	return 1;
}

sub _check_omit_start_head
{
	my ($self, $element) = @_;
	my @kids = $element->childNodes;
	return (@kids and $kids[0]->nodeType==XML_ELEMENT_NODE);
}

sub _check_omit_start_html
{
	my ($self, $element) = @_;
	my @kids = $element->childNodes;
	return (@kids and $kids[0]->nodeName ne '#comment');
}

sub _check_omit_start_tbody
{
	my ($self, $element) = @_;
	
	my @kids = $element->childNodes;
	return 0 unless @kids;
	return 0 unless $kids[0]->nodeName eq 'tr';
	return 1 unless defined $element->previousSibling;
	
	return 1
		if $element->previousSibling->nodeName eq 'tbody'
		&& $self->_check_omit_end_tbody($element->previousSibling);

	return 1
		if $element->previousSibling->nodeName eq 'thead'
		&& $self->_check_omit_end_thead($element->previousSibling);

	return 1
		if $element->previousSibling->nodeName eq 'tfoot'
		&& $self->_check_omit_end_tfoot($element->previousSibling);
}

1;

__END__

=head1 NAME

HTML::HTML5::Writer - output a DOM as HTML5

=head1 VERISON

0.03

=head1 SYNOPSIS

 use HTML::HTML5::Writer;
 
 my $writer = HTML::HTML5::Writer->new;
 print $writer->document($dom);

=head1 DESCRIPTION

This module outputs XML::LibXML::Node objects as HTML5 strings.
It works well on DOM trees that represent valid HTML/XHTML
documents; less well on other DOM trees.

=head2 Constructor

=over 4

=item C<< $writer = HTML::HTML5::Writer->new(%opts) >>

Create a new writer object. Options include:

=over 4

=item * B<markup>

Choose which serialisation of HTML5 to use: 'html' or 'xhtml'.

=item * B<polyglot>

Set to '1' in order to attempt to produce output which works as
both XML and HTML.

=item * B<doctype>

Set this to a string to choose which <!DOCTYPE> tag to output.
Note, this purely sets the <!DOCTYPE> tag and does not change
how the rest of the document is output.

The following constants are provided for convenience:
DOCTYPE_HTML5, DOCTYPE_LEGACY, DOCTYPE_NIL, DOCTYPE_HTML32,
DOCTYPE_HTML4, DOCTYPE_XHTML1, DOCTYPE_XHTML11,
DOCTYPE_XHTML_BASIC, DOCTYPE_XHTML_RDFA.

Defaults to DOCTYPE_HTML5.

=item * B<encoding>

This module always returns strings in Perl's internal utf8
encoding, but you can set the 'encoding' option to
'ascii' to create output that would be suitable for re-encoding
to ASCII (e.g. it will entity-encode characters which do not
exist in ASCII).

=item * B<quote_attributes>

Set this to a 'force' to force attributes to be quoted. Otherwise,
the writer will automatically detect when attributes need quoting.

=item * B<voids>

Set to 'slash' to force void elements to always be terminated with
'/>'. Otherwise, they'll only be terminated that way in polyglot
or XHTML documents.

=item * B<start_tags> and B<end_tags>

Except in polyglot and XHTML documents, some elements allow their
start and/or end tags to be omitted in certain circumstances. By
setting these to 'force', you can prevent them from being omitted.

=item * B<refs>

Special characters that can't be encoded as named entities need
to be encoded as numeric character references instead. These
can be expressed in decimal or hexadecimal. Setting this option to
'dec' or 'hex' allows you to choose. The default is 'hex'.

=back

=back

=head2 Public Methods

=over 4

=item C<< $writer->is_xhtml >>

Boolean indicating if $writer is configured to output XHTML.

=item C<< $writer->is_polyglot >>

Boolean indicating if $writer is configured to output polyglot HTML.

=item C<< $writer->document($node) >>

Outputs (i.e. returns a string that is) an XML::LibXML::Document as HTML.

=item C<< $writer->element($node) >>

Outputs an XML::LibXML::Element as HTML.

=item C<< $writer->attribute($node) >>

Outputs an XML::LibXML::Attr as HTML.

=item C<< $writer->text($node) >>

Outputs an XML::LibXML::Text as HTML.

=item C<< $writer->cdata($node) >>

Outputs an XML::LibXML::CDATASection as HTML.

=item C<< $writer->comment($node) >>

Outputs an XML::LibXML::Comment as HTML.

=item C<< $writer->doctype >>

Outputs the writer's DOCTYPE.

=item C<< $writer->encode_entities($string, characters=>$more) >>

Takes a string and returns the same string with some special characters
replaced. These special characters do not include any of '&', '<', '>'
or '"', but you can provide a string of additional characters to treat as
special:

 $encoded = $writer->encode_entities($raw, characters=>'&<>"');

=item C<< $writer->encode_entity($char) >>

Returns $char entity-encoded. Encoding is done regardless of whether 
$char is "special" or not.

=back

=head1 BUGS AND LIMITATIONS

Certain DOM constructs cannot be output in non-XML HTML. e.g.

 my $xhtml = <<XHTML;
 <html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Test</title></head>
  <body><hr>This text is within the HR element</hr></body>
 </html>
 XHTML
 my $dom    = XML::LibXML->new->parse_string($xhtml);
 my $writer = HTML::HTML5::Writer->new(markup=>'html');
 print $writer->document($dom);

In HTML, there's no way to serialise that properly in HTML. Right
now this module just outputs that HR element with text contained
within it, a la XHTML. In future versions, it may emit a warning
or throw an error.

In these cases, the HTML::HTML5::{Parser,Writer} combination is
not round-trippable.

Outputting elements and attributes in foreign (non-XHTML)
namespaces is implemented pretty naively and not thoroughly
tested. I'd be interested in any feedback people have, especially
on round-trippability of SVG, MathML and RDFa content in HTML.

Please report any bugs to L<http://rt.cpan.org/>.

=head1 SEE ALSO

L<HTML::HTML5::Parser>, L<HTML::HTML5::Sanity>, 
L<XML::LibXML>, L<XML::LibXML::Debugging>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Toby Inkster

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8 or,
at your option, any later version of Perl 5 you may have available.


=cut