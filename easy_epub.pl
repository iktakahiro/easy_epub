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

my $e = epub->new({script=>$SCRIPT});

my $textfile = shift(@ARGV);
if($textfile eq 'pack'){
	print "\npacking EPUB3...\n";
	my $epub_file = $e->packing_zip({});
	if(ref($epub_file) && $epub_file->{filename} ){
		printf qq{\ndone --- %s\n\n},$epub_file->{filename};
	}
	else{
		printf qq{\nNot found --- EPUB FILES\n};
	}
	exit;
}
if($textfile eq 'email-regist'){
	if( @ARGV != 2 ){
		printf qq{perl %s email-regist EPUBFILE EMAILFILE\n}, $SCRIPT;
		exit;
	}
	my ($epubfile)  = grep(/\.epub$/, @ARGV);
	my ($emailfile) = grep(!/\.epub$/, @ARGV);
	$e->regist_email({emails=>$emailfile, epub=>$epubfile});
	exit;
}
if($textfile eq 'email-check'){
	if( @ARGV != 2 ){
		printf qq{perl %s email-check EPUBFILE EMAILFILE\n}, $SCRIPT;
		exit;
	}
	my ($epubfile)  = grep(/\.epub$/, @ARGV);
	my ($emailfile) = grep(!/\.epub$/, @ARGV);
	$e->check_regist_email({emails=>$emailfile, epub=>$epubfile});
	exit;
}
if(! -f $textfile){
	print "Not found --- $textfile";
	exit;
}
my @body; my $is_docx;
my $page_style = 0;
if($textfile =~ m!\.docx!i){
	my $docx = $e->docx2text($textfile); $docx->{text} = Encode::encode('utf8', $docx->{text}) if Encode::is_utf8($docx->{text});
	@body = split(/\r?\n/, $docx->{text});
	$page_style = $docx->{page_style};
	$is_docx = 1;
}
else{
	open(IN, $textfile) || die "Not found --- $textfile"; @body = <IN>; close(IN);
}

opendir(DIR, $e->{original_images_dir}) || die "Not found --- IMAGE DIR" . $e->{original_images_dir};
if(! -e $e->{original_images_dir} . 'cover.jpg'){
	die "Not found --- cover.jpg";
}
closedir(DIR);
$e->clean_dir();
my $enc;
eval {
	my $guess = Encode::Guess->guess( join('', @body) );
	$enc = $guess->name if( ref($guess) );
};
$enc = 'utf8' if ! $enc;
if( $@ ){ die 'encode error --- ' . $@; }
# bom 対策
my $bom = Encode::encode('utf8', "\x{FEFF}");
$body[0] = substr($body[0], 3) if substr($body[0],0,3) eq $bom;
#
my $ruby; my $tcy;
my ($title, $author, $illustrator, $design, $editor, $publisher, $cover, $copyright); my @date_publish;
my $buf; my $sw; my $num=0; my $nav; my $komidashi; my $komidashi_cnt=0;
my $used_images;
my $has_block_style;
my $has_display_index;
my $put_span;
foreach(@body){
	my $line = Encode::decode($enc, $_);
	if( ! $sw ){
		$line =~ s!\r?\n!!, $title = $line,       next if($line =~ s!^[ 　]*[（\(][（\(]小説タイトル[）\)][）\)][ 　]*!! );
		$line =~ s!\r?\n!!, $author = $line,      next if($line =~ s!^[ 　]*[（\(][（\(]小説著者[）\)][）\)][ 　]*!! );
		$line =~ s!\r?\n!!, $copyright = $line,      next if($line =~ s!^[ 　]*[（\(][（\(]小説著作権[）\)][）\)][ 　]*!! );
		$line =~ s!\r?\n!!, $illustrator = $line, next if($line =~ s!^[ 　]*[（\(][（\(]小説イラストレーター[）\)][）\)][ 　]*!! );
		$line =~ s!\r?\n!!, $design = $line,      next if($line =~ s!^[ 　]*[（\(][（\(]小説デザイン[）\)][）\)][ 　]*!! );
		$line =~ s!\r?\n!!, $cover = $line,      next if($line =~ s!^[ 　]*[（\(][（\(]小説装幀[）\)][）\)][ 　]*!! );
		$line =~ s!\r?\n!!, $editor = $line,      next if($line =~ s!^[ 　]*[（\(][（\(]小説編集[）\)][）\)][ 　]*!! );
		$line =~ s!\r?\n!!, $publisher = $line,   next if($line =~ s!^[ 　]*[（\(][（\(]小説発行者[）\)][）\)][ 　]*!! );
		$line =~ s!\r?\n!!, push(@date_publish,$line),  next if($line =~ s!^[ 　]*[（\(][（\(]小説発行日[）\)][）\)][ 　]*!! );
		$line =~ s!\r?\n!!, $page_style = 1,      next if($line =~ s!^[ 　]*[（\(][（\(]小説横書き[）\)][）\)][ 　]*!! );
		$line =~ s!\r?\n!!, $has_block_style = 1, next if($line =~ s!^[ 　]*[（\(][（\(]ブロックスタイルあり[）\)][）\)][ 　]*!! );
		$line =~ s!\r?\n!!, $has_display_index = 1, next if($line =~ s!^[ 　]*[（\(][（\(]表示用目次作成[）\)][）\)][ 　]*!! );
		$line =~ s!\r?\n!!, $put_span = 1,        next if($line =~ s!^[ 　]*[（\(][（\(]句読点でspanタグ[）\)][）\)][ 　]*!! );
		$line =~ s!\r?\n!!, $put_span = 2,        next if($line =~ s!^[ 　]*[（\(][（\(]句点でspanタグ[）\)][）\)][ 　]*!! );
		if( ! $is_docx ){
			$line =~ s!\r?\n!!, $tcy = 1, next if($line =~ s!^[ 　]*[（\(][（\(]縦中横[）\)][）\)][ 　]*!! );
			if($line =~ s!^[ 　]*[（\(][（\(]小説ルビ[）\)][）\)][ 　]*!! ){
				$line =~ s!\r?\n!!;
				$ruby = $e->set_ruby({ruby=>$line});
				next;
			}
		}
	}
	$sw = 1 if $line =~ m!^([ 　]*[（\(]小見出し[）\)]|[ 　]*[（\(][（\(]扉タイトル[）\)][）\)])!;
	if( $line =~ s!^[ 　]*[（\(]小見出し[）\)][ 　]*!!){
		if( $buf ){
			$e->put_html({num=>$num,body=>$buf,title=>$title});
			++$num;
		}
		$line =~ s!\r?\n!!;
		$nav->{$num} = $line;
		$line = $e->put_span_for_media_overlays({line=>$line,span=>$put_span}) if $put_span;
		$buf = sprintf qq{<h2 class="komidashi0">%s</h2>\n}, $line;
		next;
	}
	elsif($line =~ s!^[ 　]*[（\(][（\(]扉タイトル[）\)][）\)][ 　]*!! ){
		if($buf){
			$e->put_html({num=>$num,body=>$buf,title=>$title});
			++$num;
			$buf = "";
		}
		$line =~ s!\r?\n!!;
		my ($main, $sub) = split(/\t/, $line);
		my $titlepage_body = '<div class="horizontal tobira-page"><div class="tobira-text">';
		if( $sub ){
			if($put_span){
				$main = $e->put_span_for_media_overlays({line=>$main,span=>$put_span});
				$sub  = $e->put_span_for_media_overlays({line=>$sub,span=>$put_span});
			}
			$titlepage_body .= '<h1>' . $main . '</h1>';
			$titlepage_body .= sprintf qq{<p class="subtitle">%s</p>}, $sub;
		}
		else{
			$line = $e->put_span_for_media_overlays({line=>$line,span=>$put_span}) if $put_span;
			$titlepage_body .= '<h1>' . $line . '</h1>';
		}
		$titlepage_body .= '</div></div>';
		$e->put_html({
			num=>$num,
			body=>$titlepage_body,
			title=>$title,
			bodyclass=>'',
			option=>'is_tobira'
					 });
		$nav->{$num} = ($sub ? $main : $line) . "\t" . 'is_tobira';
		++$num;
		$komidashi_cnt = 0;
		next;
	}
	elsif( $line =~ m!^[0-9a-zA-Z_-]+\.(?:jpg|png)$!i ){
		$line =~ s!\r?\n!!;
		if($buf){
			$e->put_html({num=>$num,body=>$buf,title=>$title});
			++$num;
			$buf = "";
		}
		$used_images->{$line}++;
		$e->put_html({
			num=>$num,
			body=>sprintf(qq{<div class="sashie"><img src="../images/%s" alt="-" /></div>}, $line),
			title=>$title
		});
		$line =~ s!\r?\n!!;
		++$num;
		$komidashi_cnt = 0;
		next;
	}
	if( $sw ){
		$line =~ s!\r?\n!!;
		if(! $line ){
			$line = '　';
		}
		else{
			$line =~ s!^[\t 　]+!!;
		}

		if($has_block_style && $line =~ m!^<! && $line !~ m!^<(span|ruby)!){
			$buf .= $line;
			next;
		}
		$buf .= $line, next if($line =~ s!^[\(（]改ページ[）\)].*$!<div class="pagebreak-after"></div>! );


		my $class;
		if($line =~ m!^[\(（](?:了|完|終)[）\)]$!){
			$class="endmark";
		}
		elsif($line =~ m!^(?:●|◆|◎)$!){
			$class="kugirimark";
		}
		elsif( $line =~ m!^[（［“「｢『【（〈《［\[]!){
			$class="";
		}
		else{
			$class = 'line-indent1';
		}
		if( $class ){$class = sprintf qq{class="%s"}, $class;}

		if($line =~ m!^([0-9a-zA-Z_-]+\.(?:jpg|png))[ 　]+(\d+)!){
			$used_images->{$1}++;
			$line = sprintf qq{<div class="image-wrap" style="width:%s%%; width:%svw;"><img src="../images/%s" alt="" /></div>\n}, $2, $2, $1;
		}
		elsif($line =~ s!^[ 　]*[（\(]小見出し[2２][）\)][ 　]*!!){
			$komidashi->{$num}->{++$komidashi_cnt} = $line;
			$line = $e->put_span_for_media_overlays({line=>$line,span=>$put_span}) if $put_span;
			$line = sprintf qq{<h2 class="komidashi" id="content%03d">%s</h2>\n}, $komidashi_cnt, $line;
		}
		else{
			if(! $page_style && $tcy ){
				$line =~ s!<([^>]+)>!$e->tcy_esc0($1)!ge;
				$line =~ s!([0-9][0-9]+|\!\!|\!\?|\?\!)!<span class="tcy">$1</span>!g;
				$line =~ s!<([^>]+)>!$e->tcy_esc1($1)!ge;
			}
			if(ref($ruby)){
				foreach my $word (keys %{$ruby}){
					if( $line =~ s!$word!<ruby>$word<rt>$ruby->{$word}</rt></ruby>! ){
	   					delete $ruby->{$word};
					}
				}
			}
			elsif($ruby eq 'has_ruby_text'){
				$line =~ s![ \|]?([\p{InCJKUnifiedIdeographs}\x{3005}]+[\p{InHiragana}\p{InKatakana}]*)\(([\p{InHiragana}\p{InKatakana}]+)\)!<ruby>$1<rt>$2</rt></ruby>!g;
#				$line =~ s![ \|]?([\p{InCJKUnifiedIdeographs}]+\x{3005}?[\p{InHiragana}\p{InKatakana}\x{3005}]*)\(([\p{InHiragana}\p{InKatakana}]+)\)!<ruby>$1<rt>$2</rt></ruby>!g;
			}
			if($line eq '　'){ # for blank line 2014-03-27 09:01:29
				$line = $e->put_span_for_media_overlays({line=>$line,span=>$put_span}) if $put_span;
				$line = sprintf qq{<p>%s</p>\n},$line;
			}
			else{
				$line = $e->put_span_for_media_overlays({line=>$line,span=>$put_span}) if $put_span;
				$line = sprintf qq{<p %s>%s</p>\n},$class, $line;
			}
		}

		$buf .= $line;
	}
	
}
close(IN);
if($buf){
	$e->put_html({num=>$num,body=>$buf,title=>$title});
}
if(! $sw ){
	print "Not Found --- KOMIDASHI or TOBIRA ?\n";
	exit;
}
$e->put_images({used_images=>$used_images});
$e->put_option_styles({page_style=>$page_style});

$e->put_html({
	num=>$num,
	body=>sprintf(qq{<div class="horizontal tobira-page"><div class="tobira-text"><h1>%s</h1></div></div>\n}, $put_span ? $e->put_span_for_media_overlays({line=>$title,span=>$put_span}) : $title),
	title=>$title,
	bodyclass=>'',
	option=>'title_tobira'
  });

my $optionpage = $e->check_optionpage();
my $bookslist =  $e->check_bookslist({num=>$num});
$e->nav_html({nav=>$nav, komidashi=>$komidashi, title=>$title, add=>{bookslist=>$bookslist, optionpage=>$optionpage, display_index=>$has_display_index, put_span=>$put_span}});
$e->content_opf({
	num=>$num, title=>$title,
	page_style=>$page_style,
	author=>$author,
	illustrator=>$illustrator,
	design=>$design,
	editor=>$editor,
	publisher=>$publisher,
	add=>{bookslist=>$bookslist, optionpage=>$optionpage, display_index=>$has_display_index}
});
$e->okuduke({title=>$title, author=>$author, cover=>$cover, copyright=>$copyright, illustrator=>$illustrator, design=>$design, editor=>$editor, publisher=>$publisher, ymd=>\@date_publish, put_span=>$put_span});
$e->cover({title=>$title});

$e->override_page();

my $epub_file = $e->packing_zip({});

printf qq{\ndone --- %s\n\n},$epub_file->{filename};
if(ref($ruby) eq 'HASH' && keys %{$ruby}){
	my $log = $epub_file->{filename}; $log =~ s!\.epub!!i; $log = $e->{app_dir} . $log;
	open(LOG, '>'. $log . '_ruby.log') || die; binmode LOG=>'utf8';
	print LOG qq{※以下のルビが不明でした。\n-------------------------\n};
	foreach (keys %{$ruby}){
		printf LOG qq{%s\t%s\n}, $_, $ruby->{$_};
	}
	close(LOG);
}

#
#
#
package epub;
use strict;
use utf8;
use Encode;
use Encode::Guess qw/ euc-jp shiftjis 7bit-jis utf8 /;
$Encode::Guess::NoUTFAutoGuess = 1; # utf16 utf32 を候補から外す

sub new{
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;
	my $args = shift;

	my $app_dir = ($args->{script} =~ m!script!) ? '../../../' : '';
	my ( $obj )  = bless {
		'app_dir'=>$app_dir,
		'original_images_dir' => $app_dir . 'original_images/',
		'additional_dir'      => $app_dir . 'additional_page/',
		'option_styles_dir'   => $app_dir . 'option_styles/',
		'override_dir'        => $app_dir . 'override/',
		'dir_html'   => $app_dir . 'OEBPS/text/',
		'dir_images' => $app_dir . 'OEBPS/images/',
		'dir_style'  => $app_dir . 'OEBPS/style/',
		'dir_multimedia' => $app_dir . 'OEBPS/multimedia/',
		'opf'        => $app_dir . 'OEBPS/content.opf',
		'container'  => $app_dir . 'META-INF/container.xml',
		'mimetype'   => $app_dir . 'mimetype',
		'navigation' =>'nav.xhtml',
		'okuduke'    =>'okuduke.xhtml',
		'cover'      =>'cover.xhtml',
		'display_index'=>'display_index.xhtml',
		'base'       =>'contents',
		'url'        =>'http://t2aki.doncha.net/',
		'publisher'  =>'doncha.net',
		%$args,
		@_
	}, $class;
	return $obj;
}
sub DESTROY{
	my $self = shift;
	exit;
}
sub put_html{
	my $self = shift;
	my $args = shift;

	$args->{body} =~ s!(<p>　</p>)+$!!;
	my $xhtml;
	if($args->{option} eq 'title_tobira'){
		$xhtml =  sprintf qq{%stitle.xhtml\n}, $self->{dir_html};
	}
	else{
		$xhtml =  sprintf qq{%s%s%03d.xhtml\n}, $self->{dir_html}, $self->{base}, $args->{num};
	}
	open(OUT, '>' . $xhtml) || die;
	binmode OUT=>":utf8";
	print OUT $self->html_head({title=>$args->{title}, bodyclass=>$args->{bodyclass}});
	print OUT $args->{body};
	print OUT $self->html_tail({});
	close(OUT);
}

sub html_head{
	my $self = shift;
	my $args = shift;

	my $bodyclass = $args->{bodyclass} ? sprintf( qq{class="%s"}, $args->{bodyclass}) : '';
	my $content = qq{<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja"
      xmlns:epub="http://www.classpf.org/2007/ops">
<head>
  <link href="../style/reset.css" rel="stylesheet" type="text/css" />
  <link rel="stylesheet" type="text/css" href="../style/bookstyle.css" />
  <title>$args->{title}</title>
</head>
<body $bodyclass>
};
	return $content;
}
sub html_tail{
	my $self = shift;
	my $args = shift;
	my $content = qq{</body></html>};
	return $content;
}
sub nav_html{
	my $self = shift;
	my $args = shift;
	my $head = qq{<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html >
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="ja" lang="ja">
  <head>
    <link href="../style/reset.css" rel="stylesheet" type="text/css" />
    <link rel="stylesheet" href="../style/nav.css" type="text/css" />
    <title>目次</title>
  </head>
  <body>
};
	my $tail = qq{
  </body>
</html>
};

	# navigation
	my $body = qq{
    <nav epub:type="toc" id="nav">
      <h1>目次</h1>
      <ol>
};
	###
	my $max; foreach (sort {$b<=>$a;} keys %{$args->{nav}}){ $max = $_, last; }
	my $stat; my $komidashi_stat;
	foreach my $num (0..$max){
		my( $line, $attr ) = split(/\t/, $args->{nav}->{$num});
		$line =~ s!<rt>([^<]+)</rt>!!g; $line =~ s!<[^>]+>!!g;
		if( $args->{nav}->{$num} ){
			if($komidashi_stat){
				$body .= sprintf qq{</ol>\n</li>\n};
				if($attr eq 'is_tobira' && $stat == 2 ){
					$body .= sprintf qq{</ol>\n</li>\n};
				}
				$komidashi_stat = 0;
			}
			elsif( $stat == 1 && $attr ne 'is_tobira' ){
				$body .= sprintf qq{\n<ol>\n};
				$stat = 2;
			}
			elsif($num > 0){
				$body .= sprintf qq{</li>\n};
				if( $attr eq 'is_tobira' && $stat == 2 ){
					$body .= sprintf qq{</ol>\n</li>\n};
				}
			}
			$body .= sprintf qq{<li><a href="%s%03d.xhtml">%s</a>},$self->{base}, $num, $line;
		}
		if( ref($args->{komidashi}->{$num}) ){
			$body .= sprintf qq{\n<ol>\n}, $komidashi_stat = 1 if(! $komidashi_stat );
			foreach ( sort {$a<=>$b;} keys %{$args->{komidashi}->{$num}} ){
				$args->{komidashi}->{$num}->{$_} =~ s!<[^>]+>!!g;
				$body .= sprintf qq{<li class="le2"><a href="%s%03d.xhtml#content%03d">%s</a></li>\n},
				$self->{base}, $num, $_, $args->{komidashi}->{$num}->{$_};
			}
		}
		if( $args->{nav}->{$num} &&  $attr eq 'is_tobira'){
			$stat = 1;
		}
	}
	if( $stat == 2){
		$body .= sprintf qq{</li>\n</ol>\n};
	}
	elsif($komidashi_stat){
		$body .= sprintf qq{</ol>\n};
	}
	$body .= sprintf qq{</li>\n};
	###
	if($args->{add}->{optionpage}){
		foreach( sort keys %{ $args->{add}->{optionpage}->{xhtml} }){
			$body .= sprintf qq{<li><a href="%s">%s</a></li>\n}, $_,
			$_ =~ m!option0! ? '参考文献' : $_ =~ m!option1! ? '著者紹介' : '初出一覧';
		}
	}
	$body .= sprintf qq{<li><a href="okuduke.xhtml">奥付</a></li>\n};
	if( $args->{add}->{bookslist}->{xhtml} ){
		$body .= sprintf qq{<li><a href="%s">作品一覧</a></li>\n}, $args->{add}->{bookslist}->{xhtml};
	}
	$body .= qq{
      </ol>
    </nav>
};
	if($args->{add}->{display_index}){
		if($args->{add}->{put_span}){
			$body =~ s!(<a[^>]+>)([^<]+)(</a>)!$1<span class="media-overlays">$2</span>$3!g;
		}
		open(OUT, '>' . $self->{dir_html} . $self->{display_index}) || die;
		binmode OUT=>":utf8";
		print OUT $head . $body . $tail;
		close(OUT);
	}

	# landmarks
	$body .= qq{
    <nav epub:type="landmarks" id="landmarks" hidden="hidden">
      <h2>Guide</h2>
      <ol>
};
	$body .= qq{<li><a epub:type="cover" href="cover.xhtml">表紙</a></li>\n};
	$body .= sprintf qq{<li><a epub:type="titlepage" href="title.xhtml">タイトル</a></li>\n};
	if($args->{add}->{display_index}){
		$body .= sprintf qq{<li><a epub:type="toc" href="%s">目次</a></li>\n}, $self->{display_index};
	}
	else{
		$body .= sprintf qq{<li><a epub:type="toc" href="%s">目次</a></li>\n}, $self->{navigation};
	}
	$body .= sprintf qq{<li><a epub:type="bodymatter" href="%s%03d.xhtml">本文</a></li>\n}, $self->{base}, 0;
	$body .= qq{
      </ol>
    </nav>
};
	open(OUT, '>' . $self->{dir_html} . $self->{navigation}) || die;
	binmode OUT=>":utf8";
	print OUT $head . $body . $tail;
	close(OUT);
}

sub content_opf{
	my $self = shift;
	my $args = shift;

	$args->{title} = 'タイトル' if ! $args->{title};
	$args->{author} = '著者名' if ! $args->{author};
	my $page_progression_direction = $args->{page_style} ? 'ltr':'rtl';

	my $creators;
	if($args->{illustrator}){
		$creators .= qq{
<dc:creator id="creator1">$args->{illustrator}</dc:creator>
<meta refines="#creator1" property="role" scheme="marc:relators">ill</meta>
};
	}
	if($args->{design}){
		$creators .= qq{
<dc:creator id="creator2">$args->{design}</dc:creator>
<meta refines="#creator2" property="role" scheme="marc:relators">dsr</meta>
};
	}
	if($args->{editor}){
		$creators .= qq{
<dc:creator id="creator3">$args->{editor}</dc:creator>
<meta refines="#creator3" property="role" scheme="marc:relators">edt</meta>
};
	}
	if($args->{publisher}){
		$creators .= qq{
<dc:publisher id="publisher">$args->{publisher}</dc:publisher>
};
	}
	else{
		$creators .= qq{
<dc:publisher id="publisher">$self->{publisher}</dc:publisher>
};
	}

	use UUID::Tiny;
	my $bookid = create_UUID_as_string(UUID_V1);

	my $timestamp = time;
	my ($s,$mi,$h, $d,$m,$y) = (localtime($timestamp))[0..5]; ++$m; $y+=1900; my $ymd = sprintf qq{%s-%02d-%02d}, $y,$m,$d;

	opendir(DIR, $self->{dir_html}) || die;
	my @xhtml = grep(/\.xhtml/, readdir(DIR));
	closedir(DIR);
	opendir(DIR, $self->{dir_images}) || die;
	my @images = grep(/\.(jpg|png)/i, readdir(DIR));
	closedir(DIR);

    my $contents_manifest;
	my $max;
	foreach( sort @xhtml ){
		next if m!(title|nav|okuduke|cover|bookslist|display_index)\.xhtml!;
		$max = $1 if $_ =~ m!(\d+)!;
		$contents_manifest .= sprintf qq{<item id="text.%s" href="text/%s" media-type="application/xhtml+xml" />\n}, $_, $_;
	}
	foreach( sort @images ){
		next if m!cover\.jpg!;
		my $ext = $1 if $_ =~ m!\.(jpg|png)!i;
		my $type = $ext =~ m!png! ? 'png': 'jpeg';
		$contents_manifest .= sprintf qq{<item id="images.%s" href="images/%s" media-type="image/%s" />\n}, $_, $_, $type;
	}
	return if($max != $args->{num});

	$contents_manifest .= sprintf qq{<item id="nav" href="text/%s" media-type="application/xhtml+xml" properties="nav" />\n},$self->{navigation};
    my $contents_spine;
	if($args->{add}->{display_index}){
		$contents_manifest .= sprintf qq{<item id="text.%s" href="text/%s" media-type="application/xhtml+xml" />\n},$self->{display_index}, $self->{display_index};
		$contents_spine = sprintf qq{<itemref idref="text.%s" linear="yes" />\n}, $self->{display_index};
		$contents_spine .= sprintf qq{<!-- <itemref idref="nav" linear="yes" /> -->\n};
	}
	else{
		$contents_spine = sprintf qq{<itemref idref="nav" linear="yes" />\n};
	}

	for (my $i = 0; $i<=$max; $i++){
		$contents_spine .= sprintf qq{<itemref idref="text.%s%03d.xhtml" linear="yes" />\n}, $self->{base}, $i;
	}

	my $add_manifest;
	my $add_spine;
	if($args->{add}->{optionpage}){
		foreach( sort keys %{ $args->{add}->{optionpage}->{xhtml} }){
			$add_spine .= sprintf qq{<itemref idref="text.%s" linear="yes" />\n}, $_;
		}
	}
	$add_spine .= sprintf qq{<itemref idref="text.okuduke.xhtml" linear="yes" />\n};
	if( $args->{add}->{bookslist}->{xhtml}){
		$add_manifest .= sprintf qq{<item id="text.%s" href="text/%s" media-type="application/xhtml+xml" />\n},
		$args->{add}->{bookslist}->{xhtml},$args->{add}->{bookslist}->{xhtml};
		if( $args->{add}->{bookslist}->{css}){
			$add_manifest .= sprintf qq{<item id="style.%s" href="style/%s" media-type="text/css" />\n},
			$args->{add}->{bookslist}->{css},$args->{add}->{bookslist}->{css};
		}
		$add_spine .= sprintf qq{<itemref idref="text.%s" linear="yes" />\n}, $args->{add}->{bookslist}->{xhtml};
	}

	my $xml = qq{<?xml version="1.0" encoding="utf-8"?>
<package
  xmlns="http://www.idpf.org/2007/opf"
  prefix="rendition: http://www.idpf.org/vocab/rendition/#
          ebpaj: http://www.ebpaj.jp/
          fixed-layout-jp: http://www.digital-comic.jp/
          kadokawa: http://www.kadokawa.co.jp/
          access: http://www.access-company.com/2012/layout#
          ibooks: http://vocabulary.itunes.apple.com/rdf/ibooks/vocabulary-extensions-1.0/"
  unique-identifier="BookID"
  version="3.0"
  xml:lang="ja">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">

    <!-- レンダリング指定 -->
    <meta property="rendition:layout">reflowable</meta>
    <meta property="rendition:orientation">auto</meta>
    <meta property="rendition:spread">auto</meta>

    <!-- etc. -->
    <meta property="ebpaj:guide-version">1.1.3</meta>
    <meta property="kadokawa:version">1.1.0</meta>
    <meta property="ibooks:specified-fonts">true</meta>

    <dc:identifier id="BookID">urn:uuid:$bookid</dc:identifier>
    <meta refines="#BookID" property="identifier-type">uuid</meta>

    <dc:title id="title0">$args->{title}</dc:title>
    <!-- <meta refines="#title0" property="file-as">$args->{title}</meta> -->

    <dc:creator id="creator0">$args->{author}</dc:creator>
    <meta refines="#creator0" property="role" scheme="marc:relators">aut</meta>
    <!--
    <meta refines="#creator0" property="file-as">$args->{author}</meta>
    <meta refines="#creator0" property="display-seq">1</meta>
    -->
$creators
    <dc:contributor id="contributor0">$self->{publisher}</dc:contributor>
    <meta refines="#contributor0" property="role" scheme="marc:relators">mrk</meta>
    <dc:language id="language">ja</dc:language>
    <meta name="cover" content="images.cover.jpg" />
    <meta name="epub.doncha.net" content="1.0" />
    <meta property="dcterms:modified">${ymd}T09:00:00Z</meta>
  </metadata>
  <manifest>
    $contents_manifest
    <item id="text.cover.xhtml" href="text/cover.xhtml" media-type="application/xhtml+xml" />
    <item id="text.title.xhtml" href="text/title.xhtml" media-type="application/xhtml+xml" />
    <item id="text.okuduke.xhtml" href="text/okuduke.xhtml" media-type="application/xhtml+xml" />
    <item id="images.cover.jpg" href="images/cover.jpg" media-type="image/jpeg" properties="cover-image" />
    <item id="style.okuduke.css" href="style/okuduke.css" media-type="text/css" />
    <item id="style.nav.css" href="style/nav.css" media-type="text/css" />
    <item id="style.reset.css" href="style/reset.css" media-type="text/css" />
    <item id="style.bookstyle.css" href="style/bookstyle.css" media-type="text/css" />
    <!-- additional -->
    $add_manifest
  </manifest>
  <spine page-progression-direction="$page_progression_direction">
    <itemref idref="text.cover.xhtml" linear="no" />
    <itemref idref="text.title.xhtml" linear="yes" />
    $contents_spine
    <!-- additional -->
    $add_spine
  </spine>
</package>
};
	open(OUT, '>' . $self->{opf}) || die;
	binmode OUT=>":utf8";
	print OUT $xml;
	close(OUT);
}
sub check_bookslist{
	my $self = shift;
	my $args = shift;

	if(-f $self->{'additional_dir'} . 'bookslist.xhtml' ){ # for bookslist
		my $ret;
		opendir(DIR, $self->{'additional_dir'}) || die; my @files = grep(/^bookslist/, readdir(DIR)); closedir(DIR);
		link($self->{additional_dir} . 'bookslist.xhtml' , $self->{dir_html} . 'bookslist.xhtml');
		$ret->{xhtml} = 'bookslist.xhtml';
		if(-f  $self->{'additional_dir'} . 'bookslist.css'){
			link($self->{additional_dir} . 'bookslist.css' , $self->{dir_style} . 'bookslist.css');
			$ret->{css} = 'bookslist.css';
		}
		foreach (@files){
			next if !/^bookslist.+(?:jpg|png)/;
			link($self->{additional_dir} . $_, $self->{dir_images} . $_);
			$ret->{images}->{$_} = 1;
		}
		return $ret;
	}
	return undef;
}
sub check_optionpage{
	my $self = shift;
	my $args = shift;

	if(-d $self->{'additional_dir'}){
		my $ret;
		opendir(DIR, $self->{'additional_dir'}) || die;
		my @files = grep(/^option.*\.xhtml/, readdir(DIR));
		closedir(DIR);
		foreach (@files){
			next if !/^option/;
			link($self->{additional_dir} . $_,  $self->{dir_html} . $_);
			$ret->{xhtml}->{$_} = 1;
		}
		return $ret;
	}
	return undef;
}
sub okuduke{
	my $self = shift;
	my $args = shift;
	my $head = qq{<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html >
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="ja" lang="ja">
  <head>
    <link href="../style/reset.css" rel="stylesheet" type="text/css" />
    <link rel="stylesheet" href="../style/okuduke.css" type="text/css" />
    <title>目次</title>
  </head>
  <body>
};
	my $tail = qq{
  </body>
</html>
};
	my $publish;
	if( @{ $args->{ymd} } ){
		$publish = '<p class="published-date">' . join('<br />', @{ $args->{ymd} }) . '</p>';
	}
	else{
		my ($d,$m,$y) = (localtime(time))[3..5]; ++$m; $y+=1900;
		if($m == 2 ){ $d=28; }elsif($m==4 || $m==6 || $m==9 || $m==11){$d=30;}else{$d=31;}
		$publish = sprintf qq{<p class="published-date">%s年%s月%s日</p>}, $y, $m, $d;
	}

	my $body = qq{
<h1>$args->{title}</h1>
<hr />
$publish
<p class="indent_5em">著　者　　$args->{author}</p>
};
	if($args->{illustrator}){
		$body .= qq{<p class="indent_5em">イラスト　$args->{illustrator}</p>};
	}
	if($args->{design}){
		$body .= qq{<p class="indent_5em">デザイン　$args->{design}</p>};
	}
	if($args->{editor}){
		$body .= qq{<p class="indent_5em">編　集　　$args->{editor}</p>};
	}
	if($args->{publisher}){
		$body .= qq{<p class="indent_5em">発　行　　$args->{publisher}</p>};
	}
        if($args->{cover}){
                $body .= qq{<p class="indent_5em">装　幀　　$args->{cover}</p>};
        }
	$body .= qq{
		<p class="note">本書に関するお問い合わせは info\@librabuch.jp までお願いいたします。</p>
};
        if($args->{copyright}){
                $body .= qq{<p class="copyright">$args->{copyright}</p>};
        }

	if($args->{put_span}){
		$body =~ s!(<h1[^>]*>)!$1<span class="media-overlays">!g;
		$body =~ s!</h1>!</span></h1>!g;
		$body =~ s!(<p[^>]+>)!$1<span class="media-overlays">!g;
		$body =~ s!</p>!</span></p>!g;
	}

	open(OUT, '>' . $self->{dir_html} . $self->{okuduke}) || die;
	binmode OUT=>":utf8";
	print OUT $head . $body . $tail;
	close(OUT);
	
}
sub cover{
	my $self = shift;
	my $args = shift;

	my $body = qq{
<div class="coverpage">
  <img src="../images/cover.jpg" alt="cover" />
</div>
};
	open(OUT, '>' . $self->{dir_html} . $self->{cover}) || die;
	binmode OUT=>":utf8";
	print OUT $self->html_head({title=>$args->{title}});
	print OUT $body;
	print OUT $self->html_tail({});
	close(OUT);
}
sub put_images{
	my $self = shift;
	my $args = shift;

	link($self->{original_images_dir} . 'cover.jpg' , $self->{dir_images} . 'cover.jpg');
	opendir(DIR, $self->{original_images_dir}) || die; my @files = grep(!/^\./ , readdir(DIR)); closedir(DIR);
	foreach my $f ( sort @files ){
		if( $f =~ m!\.(jpg|png)!i){
			my $new = $f; $new =~ tr/[A-Z]/[a-z]/;
			next if( ! $args->{used_images}->{$new} );
			link($self->{original_images_dir} . $f, $self->{dir_images} . $new);
		}
	}
}
sub clean_dir{
	my $self = shift;
	my $args = shift;

	my $hidden = ['.DS_Store', 'Thumbs.db'];

	if( -d $self->{dir_multimedia} ){
		opendir(DIR, $self->{dir_multimedia}); my @files = grep(!/^\./ , readdir(DIR));
		foreach (@files){ unlink $self->{dir_multimedia} . $_; }
		closedir(DIR);
		rmdir $self->{dir_multimedia};
	}

	opendir(DIR, $self->{dir_html}) || die; my @files = grep(!/^\./ , readdir(DIR));
	foreach (@files){ unlink $self->{dir_html} . $_; }
	closedir(DIR);

	opendir(DIR, $self->{dir_images}) || die; my @files = grep(!/^\./ , readdir(DIR));
	foreach (@files){ unlink $self->{dir_images} . $_; }
	closedir(DIR);

	opendir(DIR, $self->{dir_style}) || die; my @files = grep(!/^\./ , readdir(DIR));
	foreach (@files){
		next if $_ =~ m!reset\.css!i;
		unlink $self->{dir_style} . $_;
	}
	closedir(DIR);

	foreach (@{$hidden}){
		unlink $self->{dir_html} . $_;
		unlink $self->{dir_images} . $_;
		unlink $self->{dir_style} . $_;
	}
	unlink $self->{opf};
}
sub put_option_styles{
	my $self = shift;
	my $args = shift;
	my $defaults = ['bookstyle.css','nav.css','okuduke.css'];
	foreach (@{ $defaults }){
		link( sprintf(qq{%s%s%s}, $self->{option_styles_dir}, $args->{page_style} ? 'yoko_':'', $_), sprintf(qq{%s%s}, $self->{dir_style}, $_) );
	}
}
sub packing_zip{
	my $self = shift;
	my $args = shift;

	my ($s,$mi,$h, $d,$m,$y) = (localtime(time))[0..5]; ++$m; $y+=1900;
	my $zip_file = sprintf qq{%s%s%02d%02d%02d%02d%02d.epub}, $self->{app_dir}, $y, $m, $d, $h, $mi, $s;
	if($args->{email}){
		$zip_file = $args->{email} . '-' . $zip_file;
	}

	use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
	my $zip = Archive::Zip->new();

	my $is_app;
	my $mimetype;
	if($self->{mimetype} =~ s!^$self->{app_dir}!!){
		$mimetype = $zip->addFile( $self->{app_dir} . $self->{mimetype}, $self->{mimetype} );
		$is_app = 1;
	}
	else{
		$mimetype = $zip->addFile( $self->{mimetype} );
	}
	$mimetype->desiredCompressionMethod( COMPRESSION_STORED );

	no strict 'refs';
	my $fh = 'FH000';
	++$fh while fileno($fh);
	opendir($fh, $self->{dir_images}); my @files = grep(!/^\./, readdir($fh));
	$self->{dir_images} =~ s!^$self->{app_dir}!! if ($is_app);
	foreach ( @files ){
		if($is_app){
			$zip->addFile( $self->{app_dir} . $self->{dir_images} . $_, $self->{dir_images} . $_);
		}
		else{
			$zip->addFile( $self->{dir_images} . $_);
		}
	}
	++$fh while fileno($fh);
	opendir($fh, $self->{dir_style}); my @files = grep(!/^\./, readdir($fh));
	$self->{dir_style} =~ s!^$self->{app_dir}!! if ($is_app);
	foreach ( @files ){
		if($is_app){
			$zip->addFile( $self->{app_dir} . $self->{dir_style} . $_, $self->{dir_style} . $_);
		}
		else{
			$zip->addFile( $self->{dir_style} . $_);
		}
	}
	++$fh while fileno($fh);
	opendir($fh, $self->{dir_html}); my @files = grep(!/^\./, readdir($fh));
	$self->{dir_html} =~ s!^$self->{app_dir}!! if ($is_app);
	foreach ( @files ){
		next if m!\.orig$!;
		if($is_app){
			$zip->addFile( $self->{app_dir} . $self->{dir_html} . $_, $self->{dir_html} . $_);
		}
		else{
			$zip->addFile( $self->{dir_html} . $_);
		}
	}
	if($is_app){
		$self->{opf} =~ s!^$self->{app_dir}!!;
		$self->{container} =~ s!^$self->{app_dir}!!;
		$zip->addFile( $self->{app_dir} . $self->{opf}, $self->{opf} );
		$zip->addFile( $self->{app_dir} . $self->{container}, $self->{container} );
	}
	else{
		$zip->addFile( $self->{opf} );
		$zip->addFile( $self->{container} );
	}
	if( $zip->writeToFileNamed($zip_file) == AZ_OK){
		$zip_file =~ s!^$self->{app_dir}!! if($is_app);
		return {filename=>$zip_file};
	}
	return;
}
sub docx2text{
	my $self = shift;
	my $docx = shift;

	my $xml = 'document.xml';
	use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
	use XML::Simple;
	my $zip = Archive::Zip->new($docx);
	$zip->extractMemberWithoutPaths('word/' . $xml);
	my $p   = XML::Simple->new;
	my $ref = $p->XMLin( $xml );
	my $page_style = ($ref->{'w:body'}->{'w:sectPr'}->{'w:textDirection'}->{'w:val'} eq 'tbRl') ? 0:1;
	my $text;
	foreach ( @{ $ref->{'w:body'}->{'w:p'} } ){
		if( ref($_->{'w:r'}) eq 'ARRAY' ){
			foreach ( @{ $_->{'w:r'} } ){
				if( defined($_->{'w:rPr'}->{'w:b'}) ){ $text.= '<b>'; }
				if( ref($_->{'w:t'}) ){
					if( $_->{'w:t'}->{content} ){
						if(! $page_style && $_->{'w:rPr'}->{'w:eastAsianLayout'}->{'w:vert'}){
							$text .= '<span class="tcy">' . $_->{'w:t'}->{content} . '</span>';
						}
						else{
							$text .= $_->{'w:t'}->{content};
						}
					}
				}
				elsif( $_->{'w:t'} ){
					if(! $page_style && $_->{'w:rPr'}->{'w:eastAsianLayout'}->{'w:vert'}){
						$text .= '<span class="tcy">' . $_->{'w:t'} . '</span>';
					}
					else{
						$text .=  $_->{'w:t'};
					}
				}
				if( defined($_->{'w:rPr'}->{'w:b'}) ){ $text .= '</b>'; }
				# ruby
				if($_->{'w:ruby'}){
					$text .= '<ruby>';
					my $rubybase;
					if( ref($_->{'w:ruby'}->{'w:rubyBase'}->{'w:r'}) eq 'ARRAY' ){
						foreach( @{ $_->{'w:ruby'}->{'w:rubyBase'}->{'w:r'} } ){
							$rubybase .= $_->{'w:t'};
						}
					}
					else{
						$rubybase = $_->{'w:ruby'}->{'w:rubyBase'}->{'w:r'}->{'w:t'};
					}
					$text .= $rubybase;
					$text .=  '<rt>' . $_->{'w:ruby'}->{'w:rt'}->{'w:r'}->{'w:t'} . '</rt></ruby>';
				}
				$text .= '<br />' if(defined $_->{'w:br'});
			}
		}
		elsif( ref($_->{'w:r'}) eq 'HASH' ){
			if( defined($_->{'w:r'}->{'w:rPr'}->{'w:b'}) ){ $text.= '<b>'; }
			if( ref($_->{'w:r'}->{'w:t'}) eq 'HASH' ){
				if(! $page_style && $_->{'w:r'}->{'w:rPr'}->{'w:eastAsianLayout'}->{'w:vert'}){
					$text .=  '<span class="tcy">'. $_->{'w:r'}->{'w:t'}->{content} . '</span>';
				}
				else{
					$text .=  $_->{'w:r'}->{'w:t'}->{content};
				}
			}
			else{
				if(! $page_style && $_->{'w:r'}->{'w:rPr'}->{'w:eastAsianLayout'}->{'w:vert'}){
					$text .=  '<span class="tcy">'. $_->{'w:r'}->{'w:t'} . '</span>';
				}
				else{
					$text .= $_->{'w:r'}->{'w:t'};
				}
			}
			if( defined($_->{'w:r'}->{'w:rPr'}->{'w:b'}) ){ $text.= '</b>'; }
		}
		$text .= "\n";
	}
	unlink $xml;
	return {text=>$text, page_style=>$page_style};
}
sub set_ruby{
	my $self = shift;
	my $args = shift;

	my $ret;
	if( ! -f $self->{app_dir} . $args->{ruby} ){
		$ret = 'has_ruby_text';
		return $ret;
	}

	open(IN, $self->{app_dir} . $args->{ruby}) || die;
	while(<IN>){
		my $line = Encode::decode('utf8', $_);
		$line =~ s!\r?\n!!;
		next if ! $line;
		next if $line =~ m!^#!;
		my @w = split(/\t/, $line);
		$ret->{$w[0]} = $w[1];
	}
	close(IN);
	return $ret;
}
sub tcy_esc0{
	my $self = shift;
	my $str = shift;
	$str =~ s!([0-9]+)!\t$1\t!;
	$str =~ tr/0123456789/abcdefghij/;
	return '<' . $str . '>';
}
sub tcy_esc1{
	my $self = shift;
	my $str = shift;
	$str =~ s!\t([abcdefghij]+)\t!$self->tcy_esc2($1)!eg;
	return '<' . $str . '>';
}
sub tcy_esc2{
	my $self = shift;
	my $str = shift;
	$str =~ tr/abcdefghij/0123456789/;
	return $str;
}
sub regist_email{
	my $self = shift;
	my $args = shift;

	return if ! $args->{emails};
	return if ! $args->{epub};
	$self->clean_dir();

	use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
	my $orig_zip = Archive::Zip->new();
	$orig_zip->read($args->{epub});
	my @members = $orig_zip->memberNames();
	foreach(@members){
		next if $_ eq $self->{mimetype};
		$orig_zip->extractMember($_, "./$_");
	}
	if( ! $self->{opf} ){
		$self->clean_dir();
		return;
	}

	my $cmd = sprintf qq{cp %s %s.orig\n}, $self->{opf}, $self->{opf};
	if($^O =~ m!MSWin!){ $cmd =~ s!^cp!copy!; $cmd =~ s!/!\\!g;}
	system($cmd);
	my $cmd = sprintf qq{cp %s%s %s%s.orig\n}, $self->{dir_html} , $self->{okuduke}, $self->{dir_html} ,$self->{okuduke};
	if($^O =~ m!MSWin!){ $cmd =~ s!^cp!copy!; $cmd =~ s!/!\\!g;}
	system($cmd);

	my @head;
	my @buf;
	open(IN, $args->{emails}) || die;
	while(<IN>){
		my %h;
		my $line = Encode::decode('shiftjis', $_);
		$line =~ s!\r?\n!!;
		my @w = split(/\t/, $line);
		@head = @w , next if ( ! @head );
		last if ! $w[0];
		@h{ @head } = @w;
		push(@buf, \%h);
	}
	close(IN);

	no strict 'refs';
	my $fh = 'FH000';
	foreach ( @buf ){
		my @update;
		if( $_->{email} =~ m!.+\@.+! ){
			my $email = $_->{email};
			open($fh, $self->{opf} . '.orig') || die;
			while(<$fh>){
				my $line = Encode::decode('utf8', $_);
				$line =~ s!</dc:title>! (in $email)</dc:title>!;
				$line =~ s!</dc:identifier>!sprintf(qq{-:%s</dc:identifier>}, $self->mk_crypt_md5({input=>$email}))!e;
				push(@update, $line);
			}
			close($fh);
			++$fh;
			open($fh, '>' . $self->{opf}); binmode $fh=>'utf8'; print $fh @update; close($fh);

			undef @update;
			++$fh;
			open($fh, $self->{dir_html} . $self->{okuduke} . '.orig') || die;
			while(<$fh>){
				my $line = Encode::decode('utf8', $_);
				$line =~ s!<p class="note">!<p class="note" style="margin:2em 0;">(This book is in $email)</p><p class="note">!;
				push(@update, $line);
			}
			close($fh);
			++$fh;
			open($fh, '>' . $self->{dir_html} . $self->{okuduke}); binmode $fh=>'utf8'; print $fh @update; close($fh);

			my $epub_file = $e->packing_zip({email=>$email});
			printf qq{\n%s\n},$epub_file->{filename};
		}
	}
	rename( $self->{opf} . '.orig', $self->{opf}) || die "$!";
	rename( $self->{dir_html} . $self->{okuduke} . '.orig' , $self->{dir_html} . $self->{okuduke} ) || die "$!";
}
sub check_regist_email{
	my $self = shift;
	my $args = shift;

	return if ! $args->{emails};
	return if ! $args->{epub};

	my @head;
	my @buf;
	no strict 'refs';
	open(IN, $args->{emails}) || die;
	while(<IN>){
		my %h;
		my $line = Encode::decode('shiftjis', $_);
		$line =~ s!\r?\n!!;
		my @w = split(/\t/, $line);
		@head = @w , next if ( ! @head );
		last if ! $w[0];
		@h{ @head } = @w;
		push(@buf, \%h);
	}
	close(IN);
	
	use XML::Simple;
	use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
	my $zip = Archive::Zip->new();

	$zip->read($args->{epub});
	$zip->extractMemberWithoutPaths($self->{opf});
	$zip->extractMemberWithoutPaths($self->{dir_html} . $self->{okuduke});
	my $p   = XML::Simple->new;
	my $ref = $p->XMLin( 'content.opf' );

	my $stat;
	my $ver;
	my ($email1, $email2, $encr);
	foreach(@{$ref->{metadata}->{meta}}){
		$ver = $_->{content},last if $_->{name} eq 'epub.doncha.net';
	}
	my $uniq = $ref->{'unique-identifier'};
	if($uniq eq $ref->{metadata}->{'dc:identifier'}->{id}){
		($encr)  = $ref->{metadata}->{'dc:identifier'}->{content} =~ m!-:(.+)$!;
		($email1) = $ref->{metadata}->{'dc:title'}->{content} =~ m!.+\(in (.+\@.+)\)!;
	}

	open(IN, 'okuduke.xhtml') || die;
	while(<IN>){
		my $line = Encode::decode('utf8', $_);
		$email2 = $1, last if($line =~ m!\(This book is in (.+\@.+)\)!);
	}
	close(IN);

	$stat->{ticket} = $encr ? 'ok' : 'ng';
	my $target;
	foreach(@buf){
		my $email = $_->{email};
		$target = $email, last if( $self->check_input({input=>$email, encr=>$encr}) );
	}
	$stat->{check}  =  $target ? $target . ' ok' : 'ng';
	$stat->{email1} =  $target && $target eq $email1 ? 'ok':'ng';
	$stat->{email2} =  $target && $target eq $email2 ? 'ok':'ng';
	$stat->{ver}    =  $ver ? $ver . ' ok': $ver . 'ng';
	foreach (sort keys %{$stat}){
		printf qq{%s ... %s\n}, $_, $stat->{$_};
	}
	unlink('content.opf');
	unlink('okuduke.xhtml');
}
#
#my $email = 'mail@mail.com';
#print $self->check_input({encr=>$self->mk_crypt_md5({input=>$email}), input=>$email});
sub mk_crypt_md5{
	my $self = shift;
	my $args = shift;
	return if ! $args->{input};
	use Digest::MD5;
	srand();
	my $salt = time;
	$salt = substr($salt, int(rand(length($salt))), 1);
	my $alph = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
	$salt .= substr($alph, int(rand(length($alph))), 1);
	# md5
	return crypt( $args->{input}, '$1$'.$salt);
}
sub check_input{
	my $self = shift;
	my $args = shift;

	return if ! $args->{input};
	return if ! $args->{encr};

	my $salt = substr($args->{encr}, 0, 2);
	return ( crypt($args->{input},$salt) eq $args->{encr} ) ? 1 : 0;
}
sub override_page{
	my $self = shift;
	my $args = shift;

	opendir(DIR, $self->{override_dir}) || return;
	my @files = grep(/\.xhtml$/, readdir(DIR));
	closedir(DIR);
	foreach my $f ( @files ){
		if(-f $self->{dir_html} . $f){
			my $cmd = sprintf qq{cp %s%s %s%s\n}, $self->{override_dir} , $f, $self->{dir_html} , $f;
			if($^O =~ m!MSWin!){ $cmd =~ s!^cp!copy!; $cmd =~ s!/!\\!g;}
			system($cmd);
		}
	}
}
sub put_span_for_media_overlays{
	my $self = shift;
	my $args = shift;

	if($args->{span} == 2){
		$args->{line} =~ s!([。][」』]*)!$1</span><span class="media-overlays">!g;
	}
	else{
		$args->{line} =~ s!([、。][」』]*)!$1</span><span class="media-overlays">!g;
	}

	if($args->{span} == 2){
		$args->{line} =~ s!([」』]+[。]?)!$1</span><span class="media-overlays">!g;
	}
	else{
		$args->{line} =~ s!([」』]+[、。]?)!$1</span><span class="media-overlays">!g;
	}

	if($args->{span}==2){
		$args->{line} =~ s!([^。>])([「『]+)!$1</span><span class="media-overlays">$2!g;
	}
	else{
		$args->{line} =~ s!([^、。>])([「『]+)!$1</span><span class="media-overlays">$2!g;
	}
	$args->{line} =~ s!<span class="media-overlays">$!!;
	$args->{line} .= '</span>' if( $args->{line} !~ m!</span>$! );
	$args->{line} =~ s!^</span>!!;
	$args->{line} =~ s!(<span class="media-overlays"></span>)!!g;
	$args->{line} = '<span class="media-overlays">' . $args->{line} if ($args->{line} !~ m!^<span class="media-overlays">!);

	my $begin0 = $args->{line} =~ s!(<span[^>]+>)!$1!g;
	my $begin1 = $args->{line} =~ s!(<span class="media-overlays">)!$1!g;
	my $end   = $args->{line} =~ s!(</span>)!$1!g;

	$args->{line} .= '</span>' if( $end < $begin0 ); # 閉じ忘れ
	
	return $args->{line};
}
1;
__END__
