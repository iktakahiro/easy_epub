#!/usr/bin/perl
#
# http://t2aki.doncha.net/?id=1366869172
#
# Copyright (c) 2014 Tetsuaki Iida
#
# This software is released under the MIT License
# http://opensource.org/licenses/mit-license.php
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE

use vars qw($SCRIPT);
($SCRIPT = $0) =~ s!.+/([^/]+$)!$1!;
use lib '.';
use strict;
use utf8;
use Encode;
use Encode::Guess qw/ euc-jp shiftjis 7bit-jis utf8 /;
$Encode::Guess::NoUTFAutoGuess = 1; # utf16 utf32 を候補から外す
# binmode STDOUT=>'utf8';

my $e = epubcheck->new({script=>$SCRIPT});
my $is_java = $e->check_java();
if(! $is_java){
	printf qq{\nNot found java\n};
	printf qq{\n---> http://java.com/ja/download/\n};
	exit;
}
my $epubcheck = $e->check_epubcheck();
unless( ref($epubcheck) ){
	printf qq{\nNot found epubcheck\n};
	exit;
}
if($epubcheck->{zipfile}){
	$epubcheck->{epubcheck} = $e->unzip({zipfile=>$epubcheck->{zipfile}});
}
if( $epubcheck->{epubcheck} ){
	my $file = shift(@ARGV);
	if( $file ){
		$e->exec_epubcheck({filename=>$file});
	}
	else{
		printf qq{\nNot found yyyymmddhhmmxx.epub\n};
		exit;
	}
}
else{
	print qq{\nNot found epubcheck\n};
	exit;
}
#
#
#
package epubcheck;
sub new{
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $args = shift;

	my ( $obj )  = bless {
		epubcheck=>'epubcheck',
		version=>'4.0.1',
		github=>'https://github.com/IDPF/epubcheck/releases/download',
		%$args,
		@_
	}, $class;
	return $obj;
}
sub DESTROY{
	my $self = shift;
	exit;
}
sub exec_epubcheck{
	my $self = shift;
	my $args = shift;

	my $cmd = sprintf qq{java -jar epubcheck-%s/%s.jar %s\n},
	$self->{version}, $self->{epubcheck}, $args->{filename};
	$cmd =~ s!/!\\!g if ($^O =~ m!MSWin!i);
	system($cmd);

}

sub check_java{
	my $self = shift;
	my $args = shift;

	my $java = ($^O =~ m!MSWin!i) ? 'java.exe': 'java';
	my $dmt  = ($^O =~ m!MSWin!i) ? ';': ':';
	my $path = ($^O =~ m!MSWin!i) ? '\\': '/';
	foreach my $d ( split($dmt, $ENV{PATH}) ){
		if(-e $d . '/' . $java){
			return $d . $path . $java;
		}
	}
	return;
}
sub has_epubcheck{
	my $self = shift;
	my $args = shift;

	my $path = ($^O =~ m!MSWin!i) ? '\\': '/';
	if(-e 'epubcheck-' . $self->{version} . $path . $self->{epubcheck} . '.jar'){
		return 'epubcheck-' . $self->{version} . $path . $self->{epubcheck} . '.jar';
	}
	return;
}
sub check_epubcheck{
	my $self = shift;
	my $args = shift;

	my $jarfile = $self->has_epubcheck;
	return {epubcheck=>$jarfile} if( $jarfile );

	my $file = 'epubcheck-' . $self->{version} . '.zip';
	use LWP::UserAgent;
	my $uri = sprintf qq{%s/v%s/epubcheck-%s.zip},$self->{github}, $self->{version},$self->{version};
	my $lwp = LWP::UserAgent->new(agent=>'Mozilla/5.0(Macintosh;U;IntelMacOSX10.8;ja-JP-mac;rv:1.9.1.5)', timeout=>10);
	my $res = $lwp->get($uri, ':content_file'=>$file);
	if($res->is_success){
		return {zipfile=>$file};
	}
	return;
}
sub unzip{
	my $self = shift;
	my $args = shift;

	use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
	my $zip = Archive::Zip->new();

	unless($zip->read($args->{zipfile}) == AZ_OK){
		return;
	}

	my @members = $zip->members();
	foreach (@members){
		print $_->fileName()."\n";
		$zip->extractMember( $_->fileName() );
	}
	unlink $args->{zipfile};

	my $jarfile = $self->has_epubcheck;
	return $jarfile ? {epubcheck=>$jarfile} : '';
}
1;
__END__
